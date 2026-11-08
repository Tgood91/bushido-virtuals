import type { ExecuteJobResult } from "../../../runtime/offeringTypes.js";
import { ROUTER_CONFIG, getRpcConfig, rpcHost } from "./lib/orchestrator-config.js";
import {
  loadPolicy,
  clampMaxSwapPct,
  effectiveMinAlignment,
  isAssetAllowed,
  safeUsd,
  clampSwapUsd,
  createDailyCap,
} from "./lib/orchestrator-policy.js";

/**
 * Swap Orchestrator Agent: Signal Alignment + Auto-Execution via CDP
 * cron: "0,15,30,45 * * * *"  — Every 15 minutes (note: never write the step form of cron inside a block comment: its "star-slash" closes the comment)
 *
 * This agent does NOT generate its own market opinion. It consumes
 * signal output from two upstream agents:
 *
 *   - Seykota   (trend-following: EMA score -7 to +7, LONG/SHORT/CLOSE)
 *   - Druckenmiller (macro/asymmetry: fundamental_signal, action ADD/HOLD/TRIM/EXIT_NOW)
 *
 * When both agents agree on direction for the same asset AND the
 * combined alignment score clears the configured threshold, the
 * orchestrator computes swap parameters and EXECUTES via CDP
 * (Coinbase Developer Platform) using the router/RPC failover chains.
 *
 * MODE: AUTO-EXECUTE
 *   - Alignment threshold met → swap executes immediately, no human gate
 *   - Alignment threshold NOT met → no action, logged as "no_trade"
 *   - Router/RPC failure → fail CLOSED (abort, alert, do not retry blindly)
 *
 * Example request:
 * {
 *   "seykota_signals": [
 *     { "asset": "ETH", "score": 6, "action": "LONG", "atr": 85.2, "current_price": 3450 }
 *   ],
 *   "druckenmiller_signals": [
 *     { "asset": "ETH", "fundamental_signal": "STRONG_BUY", "action": "ADD",
 *       "reward_risk_ratio": 5.2, "conviction": 8 }
 *   ],
 *   "portfolio": {
 *     "equity_usd": 10000,
 *     "usdc_balance": 2500,
 *     "existing_positions": { "ETH": { "size_usd": 800 } }
 *   },
 *   "min_alignment_score": 70,
 *   "max_swap_pct": 10,
 *   "dry_run": false   // if true, computes everything but does NOT call CDP
 * }
 *
 * SAFETY POLICY (lib/orchestrator-policy.js): a request is untrusted input.
 *   - Only assets on the server allowlist (ORCHESTRATOR_ALLOWED_ASSETS) are ever traded.
 *   - max_swap_pct can only LOWER the server ceiling; min_alignment_score can only RAISE the server floor.
 *   - Every swap is capped by an absolute USD ceiling and a daily cap, whatever equity or balance a request reports.
 *   - LIVE EXECUTION IS NOT WIRED in this repo: a live (non-dry-run) job fails closed instead of pretending to trade.
 */

// Routers and RPC endpoints live in lib/orchestrator-config.js (verified router identities, working RPC defaults).
const RPC_CONFIG = getRpcConfig(process.env);
// In-memory daily spend tracker (resets on restart; use durable storage before running live).
const dailyCap = createDailyCap({ capUsd: loadPolicy(process.env).dailyCapUsd });

const CDP_API_KEY_NAME = process.env.CDP_API_KEY_NAME || "";
const CDP_API_KEY_PRIVATE_KEY = process.env.CDP_API_KEY_PRIVATE_KEY || "";
const CDP_WALLET_ID = process.env.CDP_WALLET_ID || "";

type Direction = "LONG" | "SHORT" | "NEUTRAL" | "CLOSE";

interface SeykotaSignal {
  asset: string;
  score: number;          // -7 to +7
  action: string;         // LONG | SHORT | CLOSE | HOLD
  atr?: number;
  current_price?: number;
}

interface DruckenmillerSignal {
  asset: string;
  fundamental_signal: string;  // STRONG_BUY | BUY | HOLD | SELL | STRONG_SELL
  action: string;               // ADD | HOLD | TRIM | EXIT_NOW
  reward_risk_ratio?: number;
  conviction?: number;
}

interface AlignmentResult {
  asset: string;
  seykota_direction: Direction;
  druckenmiller_direction: Direction;
  aligned: boolean;
  alignment_score: number;     // 0-100
  combined_action: "EXECUTE_LONG" | "EXECUTE_SHORT" | "EXECUTE_CLOSE" | "NO_TRADE";
  rationale: string;
}

interface SwapPlan {
  asset: string;
  direction: Direction;
  from_token: string;
  to_token: string;
  amount_usd: number;
  router_attempted: string[];
  router_used: string | null;
  rpc_used: string | null;
  status: "PLANNED" | "EXECUTED" | "FAILED" | "ABORTED_NO_ALIGNMENT" | "REJECTED" | "DRY_RUN";
  tx_hash: string | null;
  error: string | null;
}

// ─── SIGNAL NORMALIZATION ────────────────────────────────────────────────────

function seykotaToDirection(sig: SeykotaSignal): Direction {
  const action = (sig.action || "").toUpperCase();
  if (action === "LONG" || sig.score >= 5) return "LONG";
  if (action === "SHORT" || sig.score <= -5) return "SHORT";
  if (action === "CLOSE") return "CLOSE";
  return "NEUTRAL";
}

function druckenmillerToDirection(sig: DruckenmillerSignal): Direction {
  const fund = (sig.fundamental_signal || "").toUpperCase();
  const action = (sig.action || "").toUpperCase();
  if (action === "EXIT_NOW") return "CLOSE";
  if (fund === "STRONG_BUY" || fund === "BUY" || action === "ADD") return "LONG";
  if (fund === "STRONG_SELL" || fund === "SELL") return "SHORT";
  return "NEUTRAL";
}

// ─── ALIGNMENT ENGINE ─────────────────────────────────────────────────────────

function computeAlignment(
  seykotaSig: SeykotaSignal | undefined,
  druckSig: DruckenmillerSignal | undefined,
  asset: string
): AlignmentResult {
  if (!seykotaSig || !druckSig) {
    return {
      asset,
      seykota_direction: "NEUTRAL",
      druckenmiller_direction: "NEUTRAL",
      aligned: false,
      alignment_score: 0,
      combined_action: "NO_TRADE",
      rationale: `Missing signal — Seykota: ${!!seykotaSig}, Druckenmiller: ${!!druckSig}. Cannot evaluate alignment without both.`,
    };
  }

  const sDir = seykotaToDirection(seykotaSig);
  const dDir = druckenmillerToDirection(druckSig);

  // CLOSE from either agent overrides everything — both must agree it's still OK to hold
  if (sDir === "CLOSE" || dDir === "CLOSE") {
    return {
      asset,
      seykota_direction: sDir,
      druckenmiller_direction: dDir,
      aligned: true,
      alignment_score: 100,
      combined_action: "EXECUTE_CLOSE",
      rationale: `${sDir === "CLOSE" ? "Seykota" : "Druckenmiller"} signals CLOSE. Closing position regardless of other agent's view — risk management overrides upside thesis.`,
    };
  }

  const directionsMatch = sDir === dDir && sDir !== "NEUTRAL";

  if (!directionsMatch) {
    return {
      asset,
      seykota_direction: sDir,
      druckenmiller_direction: dDir,
      aligned: false,
      alignment_score: 20,
      combined_action: "NO_TRADE",
      rationale: `Signal conflict: Seykota says ${sDir}, Druckenmiller says ${dDir}. No trade — agents must agree on direction before auto-execution.`,
    };
  }

  // Both agree on direction — score the strength of conviction
  let score = 50; // base for directional agreement

  // Seykota score strength (-7 to +7, abs value contributes)
  const seykotaStrength = Math.abs(seykotaSig.score || 0);
  score += Math.min(25, seykotaStrength * 3.5); // max +25 at |score|=7

  // Druckenmiller conviction (1-10) and reward/risk
  const conviction = druckSig.conviction || 5;
  score += Math.min(15, (conviction - 5) * 3); // max +15 at conviction=10

  const rr = druckSig.reward_risk_ratio || 0;
  if (rr >= 5) score += 10;
  else if (rr >= 3) score += 5;
  else if (rr > 0 && rr < 2) score -= 15; // weak asymmetry penalizes alignment

  score = Math.max(0, Math.min(100, Math.round(score)));

  const combinedAction: AlignmentResult["combined_action"] =
    sDir === "LONG" ? "EXECUTE_LONG" :
    sDir === "SHORT" ? "EXECUTE_SHORT" :
    "NO_TRADE";

  return {
    asset,
    seykota_direction: sDir,
    druckenmiller_direction: dDir,
    aligned: true,
    alignment_score: score,
    combined_action: combinedAction,
    rationale:
      `Both agents agree: ${sDir}. Seykota score: ${seykotaSig.score} (trend strength). ` +
      `Druckenmiller: ${druckSig.fundamental_signal}, conviction ${conviction}/10, R/R ${rr.toFixed ? rr.toFixed(1) : rr}:1. ` +
      `Alignment score: ${score}/100.`,
  };
}

// ─── CDP EXECUTION ────────────────────────────────────────────────────────────

/**
 * Attempts a swap via CDP, trying routers in failover order.
 * Returns the SwapPlan with execution result.
 *
 * NOTE: This function calls the CDP SDK / API. The actual CDP client
 * initialization should use CDP_API_KEY_NAME / CDP_API_KEY_PRIVATE_KEY /
 * CDP_WALLET_ID from EconomyOS-managed environment. Implementation here
 * shows the orchestration logic and router/RPC failover wiring — wire in
 * the actual @coinbase/coinbase-sdk calls in place of the placeholder.
 */
async function executeSwapViaCDP(plan: SwapPlan, dryRun: boolean): Promise<SwapPlan> {
  if (dryRun) {
    return { ...plan, status: "DRY_RUN", router_used: ROUTER_CONFIG.primary.name, rpc_used: "primary" };
  }

  if (!CDP_API_KEY_NAME || !CDP_API_KEY_PRIVATE_KEY || !CDP_WALLET_ID) {
    return {
      ...plan,
      status: "FAILED",
      error: "CDP credentials not configured (CDP_API_KEY_NAME / CDP_API_KEY_PRIVATE_KEY / CDP_WALLET_ID). Fail closed — no trade executed.",
    };
  }

  // LIVE EXECUTION IS NOT IMPLEMENTED. This used to return status "EXECUTED" with a placeholder transaction hash
  // whenever credentials were set, which told the buyer a swap had happened when nothing had. Fail closed instead.
  //
  // When wiring the real CDP / @coinbase/coinbase-sdk call, follow lib/orchestrator-policy.js `canFailOver`:
  // fail over to the next router only BEFORE a transaction is broadcast (quote / build / simulate). After
  // broadcast, keep tracking the original hash (re-sending the same signed transaction to another RPC is safe;
  // building a new one through a different router could swap twice). Consume the daily cap on success.
  return {
    ...plan,
    status: "FAILED",
    error:
      "Live execution is not implemented in this version, so no trade was made. " +
      "Use dry_run: true for a plan, or wire the CDP swap call (see swap-orchestrator-handler.ts) before going live.",
  };
}

// ─── MAIN ────────────────────────────────────────────────────────────────────

export async function executeJob(request: Record<string, any>): Promise<ExecuteJobResult> {
  // A request is untrusted: anything that is not an array of objects with a string asset is ignored, not crashed on.
  const cleanSignals = <T extends { asset: string }>(v: unknown): T[] =>
    Array.isArray(v) ? (v.filter(x => x && typeof x === "object" && typeof (x as any).asset === "string") as T[]) : [];
  const seykotaSignals: SeykotaSignal[] = cleanSignals<SeykotaSignal>(request.seykota_signals);
  const druckSignals: DruckenmillerSignal[] = cleanSignals<DruckenmillerSignal>(request.druckenmiller_signals);
  const rawPortfolio = request.portfolio && typeof request.portfolio === "object" ? request.portfolio : {};
  const portfolio = {
    equity_usd: rawPortfolio.equity_usd ?? 10000,
    usdc_balance: rawPortfolio.usdc_balance ?? 0,
    existing_positions:
      rawPortfolio.existing_positions && typeof rawPortfolio.existing_positions === "object" ? rawPortfolio.existing_positions : {},
  };
  const policy = loadPolicy(process.env);
  const minAlignmentScore = effectiveMinAlignment(request.min_alignment_score, policy);
  const maxSwapPct = clampMaxSwapPct(request.max_swap_pct, policy);
  const dryRun = request.dry_run === true;

  // Build asset universe from both signal sets
  const allAssets = new Set<string>([
    ...seykotaSignals.map(s => s.asset),
    ...druckSignals.map(s => s.asset),
  ]);

  const alignments: AlignmentResult[] = [];
  const swapPlans: SwapPlan[] = [];

  for (const asset of allAssets) {
    // Only server-approved assets may be traded: a request cannot name its own token.
    if (!isAssetAllowed(asset, policy)) {
      swapPlans.push({
        asset: String(asset).slice(0, 24),
        direction: "NEUTRAL",
        from_token: "USDC",
        to_token: String(asset).slice(0, 24),
        amount_usd: 0,
        router_attempted: [],
        router_used: null,
        rpc_used: null,
        status: "REJECTED",
        tx_hash: null,
        error: `Asset is not on the allowlist (${[...policy.allowedAssets].join(", ")}). No trade.`,
      });
      continue;
    }
    const sSig = seykotaSignals.find(s => s.asset === asset);
    const dSig = druckSignals.find(s => s.asset === asset);
    const alignment = computeAlignment(sSig, dSig, asset);
    alignments.push(alignment);

    if (alignment.combined_action === "NO_TRADE") continue;

    if (alignment.combined_action === "EXECUTE_CLOSE") {
      const existingPos = portfolio.existing_positions?.[asset];
      if (!existingPos) continue; // nothing to close

      const plan: SwapPlan = {
        asset,
        direction: "CLOSE",
        from_token: asset,
        to_token: "USDC",
        amount_usd: clampSwapUsd(existingPos.size_usd, policy, dailyCap.remaining()),
        router_attempted: [],
        router_used: null,
        rpc_used: null,
        status: "PLANNED",
        tx_hash: null,
        error: null,
      };
      if (plan.amount_usd <= 0) {
        swapPlans.push({ ...plan, status: "ABORTED_NO_ALIGNMENT", error: "Close amount is $0 after the safety caps (or no recorded position size)." });
        continue;
      }
      const executed = await executeSwapViaCDP(plan, dryRun);
      if (executed.status === "EXECUTED") dailyCap.consume(executed.amount_usd);
      swapPlans.push(executed);
      continue;
    }

    // EXECUTE_LONG or EXECUTE_SHORT — check alignment threshold
    if (alignment.alignment_score < minAlignmentScore) {
      swapPlans.push({
        asset,
        direction: alignment.combined_action === "EXECUTE_LONG" ? "LONG" : "SHORT",
        from_token: alignment.combined_action === "EXECUTE_LONG" ? "USDC" : asset,
        to_token: alignment.combined_action === "EXECUTE_LONG" ? asset : "USDC",
        amount_usd: 0,
        router_attempted: [],
        router_used: null,
        rpc_used: null,
        status: "ABORTED_NO_ALIGNMENT",
        tx_hash: null,
        error: `Alignment score ${alignment.alignment_score} below threshold ${minAlignmentScore}`,
      });
      continue;
    }

    // Compute swap size — capped by maxSwapPct of equity
    // Equity and balances come from the request, so they are only a SIZING HINT: the absolute per-swap ceiling and
    // the daily cap in clampSwapUsd below bound the damage whatever a request reports.
    const maxSwapUsd = safeUsd(portfolio.equity_usd) * (maxSwapPct / 100);
    const availableUsdc = safeUsd(portfolio.usdc_balance);

    let amountUsd: number;
    let fromToken: string;
    let toToken: string;

    if (alignment.combined_action === "EXECUTE_LONG") {
      amountUsd = clampSwapUsd(Math.min(maxSwapUsd, availableUsdc), policy, dailyCap.remaining());
      fromToken = "USDC";
      toToken = asset;
    } else {
      // EXECUTE_SHORT — assumes existing long position to unwind, or perp short via separate venue
      const existingPos = portfolio.existing_positions?.[asset];
      amountUsd = clampSwapUsd(Math.min(maxSwapUsd, safeUsd(existingPos?.size_usd)), policy, dailyCap.remaining());
      fromToken = asset;
      toToken = "USDC";
    }

    if (amountUsd <= 0) {
      swapPlans.push({
        asset,
        direction: alignment.combined_action === "EXECUTE_LONG" ? "LONG" : "SHORT",
        from_token: fromToken,
        to_token: toToken,
        amount_usd: 0,
        router_attempted: [],
        router_used: null,
        rpc_used: null,
        status: "ABORTED_NO_ALIGNMENT",
        tx_hash: null,
        error: "Computed swap amount is $0 (insufficient balance or no position to unwind)",
      });
      continue;
    }

    const plan: SwapPlan = {
      asset,
      direction: alignment.combined_action === "EXECUTE_LONG" ? "LONG" : "SHORT",
      from_token: fromToken,
      to_token: toToken,
      amount_usd: Math.round(amountUsd * 100) / 100,
      router_attempted: [],
      router_used: null,
      rpc_used: null,
      status: "PLANNED",
      tx_hash: null,
      error: null,
    };

    const executed = await executeSwapViaCDP(plan, dryRun);
    if (executed.status === "EXECUTED") dailyCap.consume(executed.amount_usd);
    swapPlans.push(executed);
  }

  const executedSwaps = swapPlans.filter(p => p.status === "EXECUTED");
  const failedSwaps = swapPlans.filter(p => p.status === "FAILED");
  const abortedSwaps = swapPlans.filter(p => p.status === "ABORTED_NO_ALIGNMENT");
  const rejectedSwaps = swapPlans.filter(p => p.status === "REJECTED");
  const noTradeAssets = alignments.filter(a => a.combined_action === "NO_TRADE");

  const summary =
    `Orchestrator cycle: ${allAssets.size} asset(s) evaluated. ` +
    `${executedSwaps.length} swap(s) executed${dryRun ? " (DRY RUN)" : ""}. ` +
    `${failedSwaps.length} failed (router/RPC exhausted). ` +
    `${abortedSwaps.length} aborted (below alignment threshold). ` +
    `${rejectedSwaps.length} rejected (asset not on the allowlist). ` +
    `${noTradeAssets.length} no-trade (signal conflict or insufficient data).`;

  return {
    deliverable: JSON.stringify({
      schema: "swap_orchestrator",
      mode: dryRun ? "DRY_RUN" : "AUTO_EXECUTE",
      executed_at: new Date().toISOString(),
      summary,
      config: {
        min_alignment_score: minAlignmentScore,
        max_swap_pct: maxSwapPct,
        max_swap_usd: policy.maxSwapUsd,
        daily_cap_remaining_usd: dailyCap.remaining(),
        allowed_assets: [...policy.allowedAssets],
        router_failover_order: Object.values(ROUTER_CONFIG).map(r => `${r.name} (${r.identity})`),
        rpc_failover_order: ["COINBASE_RPC", "FALLBACK_RPC_1", "FALLBACK_RPC_2"].map((n, i) => `${n}: ${rpcHost(Object.values(RPC_CONFIG)[i])}`),
      },
      alignments,
      swap_plans: swapPlans,
      executed_count: executedSwaps.length,
      failed_count: failedSwaps.length,
      aborted_count: abortedSwaps.length,
      rejected_count: rejectedSwaps.length,
    }),
  };
}
