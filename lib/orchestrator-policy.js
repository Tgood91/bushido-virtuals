// Safety policy for the swap orchestrator. Pure functions, no dependencies, so every rule is unit-tested.
//
// The principle: a job REQUEST is untrusted input. The buyer may ask for something safer than the server's limits
// (a smaller swap, a higher alignment bar) but can never loosen them, never name an asset the server has not
// approved, and never supply the balances the limits are computed from without an absolute ceiling on top.

export const POLICY_DEFAULTS = {
  allowedAssets: ["ETH", "WETH", "CBBTC"],
  maxSwapPctCeiling: 10, // % of (reported) equity per swap
  maxSwapUsd: 100, // absolute ceiling per swap, whatever equity or balance a request reports
  minAlignmentFloor: 70, // a request may raise this, never lower it
  dailyCapUsd: 250, // total executed per UTC day
};

const finite = (v) => typeof v === "number" && Number.isFinite(v);
const numOr = (v, d) => {
  if (v === undefined || v === null || v === "") return d;
  const n = Number(v);
  return finite(n) && n >= 0 ? n : d;
};
const pct = (v, d) => Math.min(100, numOr(v, d));

/** Server-side limits, read from the environment (never from a request). */
export function loadPolicy(env = process.env) {
  const listed = String(env.ORCHESTRATOR_ALLOWED_ASSETS || "")
    .split(",")
    .map((s) => s.trim().toUpperCase())
    .filter(Boolean);
  return {
    allowedAssets: new Set(listed.length ? listed : POLICY_DEFAULTS.allowedAssets),
    maxSwapPctCeiling: pct(env.ORCHESTRATOR_MAX_SWAP_PCT, POLICY_DEFAULTS.maxSwapPctCeiling),
    maxSwapUsd: numOr(env.ORCHESTRATOR_MAX_SWAP_USD, POLICY_DEFAULTS.maxSwapUsd),
    minAlignmentFloor: pct(env.ORCHESTRATOR_MIN_ALIGNMENT_SCORE, POLICY_DEFAULTS.minAlignmentFloor),
    dailyCapUsd: numOr(env.ORCHESTRATOR_DAILY_CAP_USD, POLICY_DEFAULTS.dailyCapUsd),
  };
}

/** The requested max swap percent can only LOWER the ceiling. */
export function clampMaxSwapPct(requested, policy) {
  const r = Number(requested);
  if (requested === undefined || requested === null || !finite(r)) return policy.maxSwapPctCeiling;
  return Math.max(0, Math.min(r, policy.maxSwapPctCeiling));
}

/** The requested alignment bar can only RAISE the floor. */
export function effectiveMinAlignment(requested, policy) {
  const r = Number(requested);
  if (requested === undefined || requested === null || !finite(r)) return policy.minAlignmentFloor;
  return Math.min(100, Math.max(r, policy.minAlignmentFloor));
}

/** Only assets on the server's allowlist may be traded (case-insensitive symbol match). */
export function isAssetAllowed(asset, policy) {
  return typeof asset === "string" && policy.allowedAssets.has(asset.trim().toUpperCase());
}

/** Requested slippage can only be tighter than the server ceiling; junk or missing means the ceiling. */
export function clampSlippageBps(requested, ceilingBps) {
  const r = Number(requested);
  if (requested === undefined || requested === null || requested === "" || !finite(r) || r < 0) return ceilingBps;
  return Math.min(r, ceilingBps);
}

/** Anything that is not a positive finite number counts as zero. */
export function safeUsd(v) {
  const n = Number(v);
  return finite(n) && n > 0 ? n : 0;
}

/** A swap amount after the absolute per-swap ceiling and what is left of today's cap. */
export function clampSwapUsd(usd, policy, remainingDailyUsd = Infinity) {
  return Math.max(0, Math.min(safeUsd(usd), policy.maxSwapUsd, remainingDailyUsd));
}

/**
 * Router failover is only safe BEFORE a transaction has been broadcast. Once it has, trying another router could
 * execute a second swap: keep tracking the original transaction hash instead (re-sending the same signed
 * transaction to another RPC is idempotent; building a new one through a different router is not).
 */
export function canFailOver(stage) {
  return stage === "quote" || stage === "build" || stage === "simulate";
}

/** In-memory spend tracker, one bucket per UTC day. Replace with durable storage if the process restarts mid-day. */
export function createDailyCap({ capUsd, now = () => Date.now() }) {
  const dayOf = (t) => new Date(t).toISOString().slice(0, 10);
  let day = dayOf(now());
  let spent = 0;
  const roll = () => {
    const d = dayOf(now());
    if (d !== day) {
      day = d;
      spent = 0;
    }
  };
  return {
    remaining() {
      roll();
      return Math.max(0, capUsd - spent);
    },
    consume(usd) {
      roll();
      spent += safeUsd(usd);
    },
  };
}
