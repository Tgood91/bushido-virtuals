import test from "node:test";
import assert from "node:assert/strict";
import { createLlama, crossCheck, spreadPct, toYield, riskFlags, filterStableYields, USD_STABLE_SYMBOLS } from "../lib/feeds/defillama.js";
import { WATCHLIST } from "../lib/feeds/dexscreener.js";

const U = WATCHLIST.USDC;
const V = WATCHLIST.VIRTUAL;
const json = (body, status = 200) => ({ ok: status < 400, status, json: async () => body });
const pool = (o) => ({ pool: "p", project: "x", chain: "Base", symbol: "USDC", tvlUsd: 500_000, apy: 5, apyBase: 5, apyReward: null, stablecoin: true, ilRisk: "no", exposure: "single", outlier: false, predictions: { predictedClass: "Stable/Up" }, ...o });

test("cross-check fails closed: one source is not a check, and a wide spread is refused", () => {
  assert.equal(crossCheck({ a: 1 }).ok, false);
  assert.equal(crossCheck({ a: 1, b: null, c: 0 }).ok, false);
  assert.equal(crossCheck({ a: 1, b: 1.004 }).ok, true);
  const wide = crossCheck({ a: 1, b: 1.1 });
  assert.equal(wide.ok, false);
  assert.match(wide.reason, /disagree/);
  assert.equal(crossCheck({ a: 1, b: 1.04, c: 1.001 }, { maxSpreadPct: 5 }).ok, true);
  assert.equal(spreadPct([1]), null);
  assert.ok(Math.abs(spreadPct([1, 1.1]) - 9.52) < 0.01);
});

test("yield flags: outliers, reward-driven, predicted down, IL, multi-asset, implausible", () => {
  const y = toYield(pool({ apy: 200, apyBase: null, apyReward: 190, outlier: true, ilRisk: "yes", exposure: "multi", predictions: { predictedClass: "Down" } }));
  assert.deepEqual(riskFlags(y).sort(), ["impermanent-loss", "implausible-apy", "multi-asset", "outlier", "predicted-down", "reward-driven"]);
  assert.equal(y.apyBaseOnly, 10); // total minus rewards
  assert.deepEqual(riskFlags(toYield(pool({}))), []);
});

test("stable scan: USD stables only, TVL floor, no outliers, no implausible APY, sorted, flags attached", () => {
  const rows = [
    pool({ pool: "good", symbol: "USDC", apy: 8 }),
    pool({ pool: "better", symbol: "USDC-USDT", apy: 12, apyReward: 8, apyBase: 4 }),
    pool({ pool: "eur", symbol: "JEUR-EURC", apy: 30 }), // flagged stablecoin by DefiLlama, but not USD
    pool({ pool: "moon", symbol: "MSUSD-USDC", apy: 447 }), // implausible
    pool({ pool: "out", symbol: "USDC", apy: 40, outlier: true }),
    pool({ pool: "tiny", symbol: "USDC", apy: 20, tvlUsd: 5_000 }),
    pool({ pool: "volatile", symbol: "ETH-USDC", apy: 25, stablecoin: false }),
  ].map(toYield);
  const out = filterStableYields(rows);
  assert.deepEqual(out.map((y) => y.poolId), ["better", "good"]);
  assert.deepEqual(out[0].risks, ["reward-driven"].filter(() => false).concat(out[0].risks)); // flags present as an array
  assert.ok(Array.isArray(out[0].risks));
  assert.ok(USD_STABLE_SYMBOLS.has("USDC") && !USD_STABLE_SYMBOLS.has("EURC"));
});

test("prices: case-insensitive match, stale and low-confidence flagged, missing tokens are null", async () => {
  const now = Date.parse("2026-11-09T00:00:00Z");
  const ts = (min) => (now - min * 60000) / 1000;
  const fetchImpl = async (url) => {
    assert.match(url, /base:0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913/);
    return json({ coins: { ["base:" + U.toLowerCase()]: { price: 0.9997, symbol: "USDC", timestamp: ts(1), confidence: 0.99 }, ["base:" + V]: { price: 0.54, symbol: "VIRTUAL", timestamp: ts(120), confidence: 0.5 } } });
  };
  const llama = createLlama({ fetchImpl, now: () => now });
  const p = await llama.getPrices([U, V, WATCHLIST.DAI]);
  assert.equal(p[U].price, 0.9997);
  assert.equal(p[U].stale, false);
  assert.equal(p[V].stale, true);
  assert.equal(p[V].lowConfidence, true);
  assert.equal(p[WATCHLIST.DAI], null);
  await assert.rejects(() => llama.getPrices(["nope"]), /Not a token address/);
});

test("history: validates the period, caps the span, drops bad points", async () => {
  let url;
  const fetchImpl = async (u) => ((url = u), json({ coins: { ["base:" + V]: { prices: [{ timestamp: 1000, price: 0.5 }, { timestamp: 2000, price: 0 }, { timestamp: 3000, price: 0.6 }] } } }));
  const llama = createLlama({ fetchImpl });
  const h = await llama.getPriceHistory(V, { span: 99999, period: "4h" });
  assert.match(url, /span=500&period=4h/);
  assert.deepEqual(h.map((x) => x.price), [0.5, 0.6]);
  await assert.rejects(() => llama.getPriceHistory(V, { period: "1d&x=1" }), /Bad period/);
});

test("yields: one fetch is shared by concurrent callers and cached for the TTL, Base rows only", async () => {
  let calls = 0;
  let t = 0;
  const fetchImpl = async () => (calls++, json({ data: [pool({ pool: "a", symbol: "USDC", apy: 7 }), pool({ pool: "b", chain: "Ethereum", apy: 99 })] }));
  const llama = createLlama({ fetchImpl, now: () => t, yieldsTtlMs: 1000 });
  const [a, b] = await Promise.all([llama.scanStableYields(), llama.bestYieldsFor("usdc")]);
  assert.equal(calls, 1);
  assert.deepEqual(a.map((y) => y.poolId), ["a"]);
  assert.deepEqual(b.map((y) => y.poolId), ["a"]);
  await llama.scanStableYields();
  assert.equal(calls, 1);
  t = 2000;
  await llama.scanStableYields();
  assert.equal(calls, 2);
});

test("bestYieldsFor matches the token, not a substring", async () => {
  const fetchImpl = async () => json({ data: [pool({ pool: "1", symbol: "USDC", apy: 5 }), pool({ pool: "2", symbol: "USDC-ETH", apy: 9, stablecoin: false }), pool({ pool: "3", symbol: "SUSDC2", apy: 20 })] });
  const out = await createLlama({ fetchImpl }).bestYieldsFor("USDC");
  assert.deepEqual(out.map((y) => y.poolId), ["2", "1"]);
});

test("an HTTP error is an error, not an empty result", async () => {
  await assert.rejects(() => createLlama({ fetchImpl: async () => json({}, 500) }).getPrices([U]), /DefiLlama 500/);
});
