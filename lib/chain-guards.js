// Pre-flight chain checks for the swap orchestrator. Pure decoding and decision functions, plus one reader that
// tries the RPC endpoints in failover order using fetch (injectable, so the tests run offline).
//
// Rule: never trade on Base while the sequencer is down, or within the grace period after it comes back up
// (prices and oracles can be stale right after a restart). Fail closed on any doubt.

import { BASE_CONTRACTS } from "./base-contracts.js";

/** Seconds to wait after the sequencer comes back up before trading again (Chainlink's recommended pattern). */
export const SEQUENCER_GRACE_PERIOD_S = 3600;

const LATEST_ROUND_DATA = "0xfeaf968c"; // latestRoundData()

/**
 * Decode latestRoundData() return data: (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound).
 * For the sequencer uptime feed, answer 0 = up, 1 = down; startedAt = when the current status began.
 */
export function decodeLatestRoundData(hex) {
  if (typeof hex !== "string" || !/^0x[0-9a-fA-F]{320}$/.test(hex)) throw new Error("unexpected latestRoundData return data");
  const word = (i) => BigInt("0x" + hex.slice(2 + i * 64, 2 + (i + 1) * 64));
  let answer = word(1);
  if (answer >= 1n << 255n) answer -= 1n << 256n; // int256
  return { roundId: word(0), answer, startedAt: word(2), updatedAt: word(3), answeredInRound: word(4) };
}

/** Decide from decoded feed data. Returns { ok, reason }. */
export function checkSequencer(round, nowS, graceS = SEQUENCER_GRACE_PERIOD_S) {
  if (!round) return { ok: false, reason: "no sequencer data" };
  if (round.answer !== 0n) return { ok: false, reason: "sequencer is DOWN" };
  if (round.startedAt === 0n) return { ok: false, reason: "sequencer feed round not initialised" };
  const upFor = BigInt(Math.floor(nowS)) - round.startedAt;
  if (upFor < BigInt(graceS)) return { ok: false, reason: `sequencer back up only ${upFor}s ago (grace period ${graceS}s)` };
  return { ok: true, reason: `sequencer up for ${upFor}s` };
}

/**
 * Read the sequencer feed, trying each RPC URL in order (RPC failover). Returns { ok, reason, rpcIndex }.
 * Any RPC error moves to the next endpoint; if all fail, the result is ok: false (abort and alert, never trade).
 */
export async function readSequencerStatus(rpcUrls, { fetchImpl = fetch, nowS = Date.now() / 1000, timeoutMs = 5000 } = {}) {
  const errors = [];
  for (const [i, url] of rpcUrls.entries()) {
    try {
      const res = await fetchImpl(url, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "eth_call", params: [{ to: BASE_CONTRACTS.sequencerFeed, data: LATEST_ROUND_DATA }, "latest"] }),
        signal: AbortSignal.timeout(timeoutMs),
      });
      const body = await res.json();
      if (body.error || !body.result) throw new Error(body.error?.message || "empty result");
      return { ...checkSequencer(decodeLatestRoundData(body.result), nowS), rpcIndex: i };
    } catch (e) {
      errors.push(`rpc[${i}]: ${e.message}`);
    }
  }
  return { ok: false, reason: `all RPCs failed (${errors.join("; ")})`, rpcIndex: null };
}
