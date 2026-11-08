// Swap execution state machine. Pure orchestration: every network or signing step is an injected adapter, so the rules
// that protect money (failover only before broadcast, simulate before sign, one broadcast, spend recorded before send)
// are tested without a chain or a key.
//
// An adapter set is { quote, build, simulate, broadcast, confirm } for ONE router:
//   quote(req)        -> { quoteId, minOutRaw }          req = { from, to, amountRaw, slippageBps }
//   build(quote, req) -> { tx }                          an unsigned transaction
//   simulate(tx)      -> { ok: boolean, reason? }        eth_call / dry run; ok:false means revert
//   broadcast(tx)     -> { hash }                        signs AND sends; called at most once per swap
//   confirm(hash)     -> { status: "success"|"reverted"|"pending" }
// `adapters` maps a router role ("primary", "fallback_1", ...) to its adapter set, in ROUTER_CONFIG order.

import { canFailOver, clampSwapUsd } from "./orchestrator-policy.js";
import { FAILOVER_POLICY, tokenFor } from "./orchestrator-config.js";

const withTimeout = (p, ms, label) =>
  Promise.race([Promise.resolve(p), new Promise((_, rej) => setTimeout(() => rej(new Error(`${label} timed out after ${ms} ms`)), ms))]);

const msg = (e) => String(e?.message || e).slice(0, 200);

/** Dollar amount to raw units of the token being sold, via a USD price per token (USDC is 1). */
export function toRawAmount(usd, token, usdPerToken) {
  // No default price: a missing or invalid price must never be read as $1.
  const price = usdPerToken;
  if (!(usd > 0) || !(price > 0) || !Number.isFinite(price)) return 0n;
  const units = usd / price;
  return BigInt(Math.floor(units * 10 ** Math.min(token.decimals, 8))) * 10n ** BigInt(Math.max(0, token.decimals - 8));
}

/**
 * Execute one planned swap.
 * deps: { adapters, policy, cap, routers (ordered [{role,name}]), slippageBps, usdPerToken?, failover? }
 * Returns the plan with status EXECUTED | PENDING | FAILED and the routers tried. It never throws.
 */
export async function executeSwap(plan, deps) {
  const failover = deps.failover || FAILOVER_POLICY.router;
  const attempted = [];
  const fail = (error, extra = {}) => ({ ...plan, router_attempted: attempted, status: "FAILED", error, ...extra });

  // Re-check the amount against what is left today, at execution time (the plan may be old, the cap may have been spent).
  const usd = clampSwapUsd(plan.amount_usd, deps.policy, deps.cap.remaining());
  if (usd <= 0) return fail("Nothing left under the per-swap or daily cap. No trade.");
  const from = tokenFor(plan.from_token);
  const to = tokenFor(plan.to_token);
  if (!from || !to) return fail("Token is not in the verified Base token table. No trade.");
  const sellsUsdc = plan.from_token.toUpperCase() === "USDC";
  const amountRaw = toRawAmount(usd, from, sellsUsdc ? 1 : deps.usdPerToken?.[plan.from_token.toUpperCase()]);
  if (amountRaw <= 0n) return fail("Could not size the swap (no price for the token being sold). No trade.");

  const req = { from, to, amountRaw, slippageBps: deps.slippageBps };

  // Stages that may fail over: quote, build, simulate. Try each router in order, one retry each.
  let ready = null;
  let lastError = "no router adapters configured";
  for (const router of deps.routers) {
    const a = deps.adapters[router.role];
    if (!a) continue;
    attempted.push(router.name);
    for (let attempt = 0; attempt <= failover.maxRetriesPerRouter && !ready; attempt++) {
      let stage = "quote";
      try {
        const quote = await withTimeout(a.quote(req), failover.timeoutMs, "quote");
        stage = "build";
        const { tx } = await withTimeout(a.build(quote, req), failover.timeoutMs, "build");
        stage = "simulate";
        const sim = await withTimeout(a.simulate(tx), failover.timeoutMs, "simulate");
        if (!sim?.ok) throw new Error(`simulation reverted${sim?.reason ? `: ${sim.reason}` : ""}`);
        ready = { router, adapter: a, tx };
      } catch (e) {
        lastError = `${router.name} ${stage}: ${msg(e)}`;
        if (!canFailOver(stage)) return fail(lastError);
      }
    }
    if (ready) break;
  }
  if (!ready) return fail(`All routers failed before broadcast (${lastError}). Abort and alert; no trade.`);

  // Record the spend BEFORE sending, so a crash or a concurrent job can never spend the same cap twice.
  deps.cap.consume(usd);

  // From here there is no failover. One broadcast only.
  let hash;
  try {
    ({ hash } = await withTimeout(ready.adapter.broadcast(ready.tx), failover.timeoutMs, "broadcast"));
  } catch (e) {
    // Unknown outcome: the transaction may or may not have been sent. Do not retry and do not release the cap.
    return fail(`${ready.router.name} broadcast: ${msg(e)}. Outcome unknown; check the wallet before retrying. Spend stays recorded.`, {
      router_used: ready.router.name,
      error_stage: "broadcast",
    });
  }
  if (typeof hash !== "string" || !/^0x[0-9a-fA-F]{64}$/.test(hash)) {
    return fail(`${ready.router.name} returned no valid transaction hash. Outcome unknown; check the wallet. Spend stays recorded.`, {
      router_used: ready.router.name,
    });
  }

  const sent = { ...plan, amount_usd: usd, router_attempted: attempted, router_used: ready.router.name, tx_hash: hash };
  try {
    const c = await withTimeout(ready.adapter.confirm(hash), failover.timeoutMs, "confirm");
    if (c?.status === "success") return { ...sent, status: "EXECUTED", error: null };
    if (c?.status === "reverted") return { ...sent, status: "FAILED", error: "Transaction reverted on chain." };
  } catch {
    /* fall through to PENDING */
  }
  // Keep tracking the ORIGINAL hash. Never build a second transaction through another router.
  return { ...sent, status: "PENDING", error: "Broadcast, not yet confirmed. Track this hash; do not resend through another router." };
}
