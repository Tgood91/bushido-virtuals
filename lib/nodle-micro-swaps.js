// nodle_micro-swaps: the orchestrator's micro-swap sub-function.
//
// Reference job (nodle-3x-daily-micro.json): 0.05 USDC -> ETH on Base, every 4 hours (3 a day), stop when USDC < 0.05.
// Here it is a PLAN only. It goes through the same safety policy and execution path as every other orchestrator swap,
// so it is dry-run unless live execution is wired, and it never runs against the agents: if Seykota and Druckenmiller
// together say SHORT or CLOSE for ETH, the micro-buy is skipped.

import { isAssetAllowed, clampSwapUsd, safeUsd } from "./orchestrator-policy.js";

export const NODLE_DEFAULTS = Object.freeze({
  amountUsd: 0.05,
  fromToken: "USDC",
  toToken: "ETH",
  maxPerUtcDay: 3,
});

/**
 * @param {object} p
 * @param {number} p.usdcBalance       reported USDC balance (a request value: only a hint, the policy caps still apply)
 * @param {string|null} p.ethAction    combined_action from the alignment engine for ETH, or null if ETH was not evaluated
 * @param {number} p.runsToday         micro-swaps already done this UTC day
 * @param {object} p.policy            loadPolicy() result
 * @param {number} p.remainingDailyUsd what is left of the orchestrator's daily cap
 * @returns {{ run: boolean, amount_usd: number, from_token: string, to_token: string, reason: string }}
 */
export function planNodleMicroSwap({ usdcBalance, ethAction = null, runsToday = 0, policy, remainingDailyUsd = Infinity }) {
  const base = { run: false, amount_usd: 0, from_token: NODLE_DEFAULTS.fromToken, to_token: NODLE_DEFAULTS.toToken };
  if (!isAssetAllowed(NODLE_DEFAULTS.toToken, policy)) return { ...base, reason: "ETH is not on the allowlist" };
  if (ethAction === "EXECUTE_SHORT" || ethAction === "EXECUTE_CLOSE")
    return { ...base, reason: `skipped: the agents say ${ethAction} for ETH` };
  if (safeUsd(runsToday) >= NODLE_DEFAULTS.maxPerUtcDay) return { ...base, reason: `already ran ${NODLE_DEFAULTS.maxPerUtcDay}x today` };
  if (safeUsd(usdcBalance) < NODLE_DEFAULTS.amountUsd)
    return { ...base, reason: `stop condition: USDC balance below ${NODLE_DEFAULTS.amountUsd}` };
  const amount = clampSwapUsd(NODLE_DEFAULTS.amountUsd, policy, remainingDailyUsd);
  if (amount < NODLE_DEFAULTS.amountUsd) return { ...base, reason: "daily cap reached" };
  return { ...base, run: true, amount_usd: amount, reason: "scheduled micro-swap" };
}
