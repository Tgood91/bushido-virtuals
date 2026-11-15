import test from "node:test";
import assert from "node:assert/strict";
import { decodeLatestRoundData, checkSequencer, readSequencerStatus, SEQUENCER_GRACE_PERIOD_S } from "../lib/chain-guards.js";
import { BASE_CONTRACTS, BASE_TOKENS, getWssConfig, DEFAULT_WSS } from "../lib/base-contracts.js";

const w = (n) => BigInt(n).toString(16).padStart(64, "0");
const encode = ({ answer = 0, startedAt = 1_000_000 }) => "0x" + w(5) + w(answer) + w(startedAt) + w(startedAt) + w(5);

// Return data captured from mainnet.base.org on 2026-11-09.
const REAL = "0x00000000000000000000000000000000000000000000000100000000000000140000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006a3ea973000000000000000000000000000000000000000000000000000000006af2020b0000000000000000000000000000000000000000000000010000000000000014";

test("decodes real sequencer feed data: answer 0 (up)", () => {
  const r = decodeLatestRoundData(REAL);
  assert.equal(r.answer, 0n);
  assert.equal(r.startedAt, 0x6a3ea973n);
  assert.equal(checkSequencer(r, Number(r.startedAt) + 7200).ok, true);
});

test("down, inside the grace period, or malformed: not ok", () => {
  assert.equal(checkSequencer(decodeLatestRoundData(encode({ answer: 1 })), 9e9).ok, false);
  assert.equal(checkSequencer(decodeLatestRoundData(encode({ startedAt: 1000 })), 1000 + SEQUENCER_GRACE_PERIOD_S - 1).ok, false);
  assert.equal(checkSequencer(decodeLatestRoundData(encode({ startedAt: 0 })), 9e9).ok, false);
  assert.equal(checkSequencer(null, 9e9).ok, false);
  assert.throws(() => decodeLatestRoundData("0x1234"));
});

test("readSequencerStatus fails over to the next RPC and fails closed when all fail", async () => {
  const calls = [];
  const fetchImpl = async (url) => {
    calls.push(url);
    if (url === "a") throw new Error("connect refused");
    if (url === "b") return { json: async () => ({ error: { message: "rate limited" } }) };
    return { json: async () => ({ result: encode({ startedAt: 1000 }) }) };
  };
  const ok = await readSequencerStatus(["a", "b", "c"], { fetchImpl, nowS: 1_000_000 });
  assert.deepEqual(calls, ["a", "b", "c"]);
  assert.equal(ok.ok, true);
  assert.equal(ok.rpcIndex, 2);
  const bad = await readSequencerStatus(["a", "b"], { fetchImpl, nowS: 1_000_000 });
  assert.equal(bad.ok, false);
  assert.match(bad.reason, /all RPCs failed/);
});

test("Base contract addresses are well formed and frozen; WSS default and override", () => {
  for (const a of [...Object.values(BASE_CONTRACTS), ...Object.values(BASE_TOKENS).map((t) => t.address)]) assert.match(a, /^0x[0-9a-fA-F]{40}$/);
  assert.equal(BASE_CONTRACTS.weth9, "0x4200000000000000000000000000000000000006");
  assert.ok(Object.isFrozen(BASE_CONTRACTS));
  assert.equal(getWssConfig({}).monitoring, DEFAULT_WSS);
  assert.equal(getWssConfig({ TENDERLY_WSS: "wss://x.example" }).monitoring, "wss://x.example");
});
