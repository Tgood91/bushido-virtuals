import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import {
  WATCHLIST, USD_STABLES, pickBestPair, toSnapshot, bucketSeries, ema, trendScore, trendToSeykotaScore,
  pegDeviationBps, checkLiquidity, priceAgreement, createFeed,
} from "../lib/feeds/dexscreener.js";

const V = WATCHLIST.VIRTUAL;
const U = WATCHLIST.USDC;
const pair = (base, quote, o = {}) => ({
  pairAddress: "0xpair", dexId: "uniswap", baseToken: { address: base, symbol: "B" }, quoteToken: { address: quote, symbol: "Q" },
  priceUsd: "2", priceNative: "0.5", liquidity: { usd: 1000 }, volume: { h24: 5 }, txns: { h24: { buys: 1, sells: 2 } }, ...o,
});
const tmp = () => path.join(fs.mkdtempSync(path.join(os.tmpdir(), "feed-")), "series.jsonl");
const json = (body, status = 200) => ({ ok: status < 400, status, json: async () => body });

test("watchlist: well-formed, unique addresses; only the USD stables get a peg check", () => {
  const addrs = Object.values(WATCHLIST).map((a) => a.toLowerCase());
  assert.equal(new Set(addrs).size, addrs.length);
  for (const a of addrs) assert.match(a, /^0x[0-9a-f]{40}$/);
  assert.deepEqual([...USD_STABLES].sort(), ["DAI", "USDBC", "USDC", "USDT"]);
});

test("pair choice: deepest liquidity, and the token may be either side", () => {
  const deep = pair("0xother", V, { liquidity: { usd: 9000 } });
  const shallow = pair(V, "0xother", { liquidity: { usd: 100 } });
  assert.equal(pickBestPair([shallow, deep], V), deep);
  assert.equal(pickBestPair([shallow], "0x" + "9".repeat(40)), null);
  assert.equal(pickBestPair(undefined, V), null);
});

test("snapshot price: base side uses priceUsd, quote side uses priceUsd / priceNative", () => {
  assert.equal(toSnapshot(pair(V, "0xo"), V).priceUsd, 2);
  assert.equal(toSnapshot(pair("0xo", V), V).priceUsd, 4); // 2 USD per base, 0.5 quote per base -> quote costs 4
  assert.equal(toSnapshot(pair("0xo", V, { priceNative: "0" }), V).priceUsd, null);
  assert.equal(toSnapshot(null, V), null);
});

test("series are bucketed by time, so uneven polling does not distort the average", () => {
  const t0 = Date.parse("2026-11-08T00:00:00Z");
  const row = (min, p) => ({ at: new Date(t0 + min * 60000).toISOString(), priceUsd: p });
  const rows = [row(0, 1), row(1, 2), row(2, 3), row(16, 4), row(31, 5), { at: "bad", priceUsd: 9 }, row(40, -1)];
  assert.deepEqual(bucketSeries(rows, 15 * 60000, t0 + 3600000), [3, 4, 5]); // last price in each 15 minute bucket
  assert.deepEqual(bucketSeries([row(500, 7)], 15 * 60000, t0), []); // the future is ignored
});

test("trend score: needs history, 50 when flat, above 50 up, below 50 down", () => {
  assert.equal(trendScore([1, 2, 3]), null);
  const n = 60;
  assert.equal(trendScore(Array(n).fill(10)), 50);
  assert.ok(trendScore(Array.from({ length: n }, (_, i) => 10 + i * 0.1)) > 50);
  assert.ok(trendScore(Array.from({ length: n }, (_, i) => 10 - i * 0.05)) < 50);
  assert.equal(ema([], 5), null);
});

test("trend maps onto the Seykota -7..+7 scale; no data gives no signal", () => {
  assert.equal(trendToSeykotaScore(50), 0);
  assert.equal(trendToSeykotaScore(100), 7);
  assert.equal(trendToSeykotaScore(0), -7);
  assert.equal(trendToSeykotaScore(500), 7);
  assert.equal(trendToSeykotaScore(null), null);
  assert.equal(trendToSeykotaScore(NaN), null);
});

test("peg deviation in basis points", () => {
  assert.equal(pegDeviationBps({ priceUsd: 0.995 }), -50);
  assert.equal(pegDeviationBps({ priceUsd: 1.01 }), 100);
  assert.equal(pegDeviationBps({ priceUsd: null }), null);
  assert.equal(pegDeviationBps(null), null);
});

test("liquidity check: a floor, a share-of-pool limit, and unknown means no", () => {
  assert.equal(checkLiquidity({ liquidityUsd: 400_000 }, { tradeUsd: 100 }).ok, true);
  assert.equal(checkLiquidity({ liquidityUsd: 5_000 }, { tradeUsd: 100 }).ok, false); // below floor
  const share = checkLiquidity({ liquidityUsd: 150_000 }, { tradeUsd: 5000 });
  assert.equal(share.ok, false);
  assert.match(share.reasons.join(), /% of the pool/);
  assert.equal(checkLiquidity({ liquidityUsd: null }, { tradeUsd: 1 }).ok, false);
  assert.equal(checkLiquidity(null, { tradeUsd: 1 }).ok, false);
});

test("price agreement: the router quote must be within the tolerance of the feed hint", () => {
  assert.deepEqual(priceAgreement(1, 1.005), { ok: true, diffBps: 50 });
  assert.equal(priceAgreement(1, 1.05).ok, false);
  assert.equal(priceAgreement(0, 1).ok, false);
  assert.equal(priceAgreement(1, NaN).ok, false);
});

test("feed: throttles, backs off once on 429, sends an honest user agent, rejects bad addresses", async () => {
  const calls = [];
  const sleeps = [];
  let first = true;
  const fetchImpl = async (url, opts) => {
    calls.push({ url, ua: opts.headers["User-Agent"] });
    if (first) { first = false; return json({}, 429); }
    return json([pair(V, "0xo")]);
  };
  const feed = createFeed({ fetchImpl, sleep: async (ms) => sleeps.push(ms), now: () => 1_000_000, seriesFile: tmp() });
  const snaps = await feed.getSnapshots([V]);
  assert.equal(snaps[V].priceUsd, 2);
  assert.equal(calls.length, 2);
  assert.ok(sleeps.includes(1500));
  assert.match(calls[0].ua, /^bushido-virtuals/);
  assert.doesNotMatch(calls[0].ua, /Mozilla/);
  await assert.rejects(() => feed.getSnapshots(["../../etc/passwd"]), /Not a token address/);
  await assert.rejects(() => createFeed({ fetchImpl: async () => json({}, 500), sleep: async () => {}, seriesFile: tmp() }).getSnapshots([V]), /DexScreener 500/);
});

test("series file: appends, survives a corrupt line, and stays bounded", () => {
  const file = tmp();
  const feed = createFeed({ seriesFile: file, maxSeriesLines: 5, now: () => Date.parse("2026-11-09T00:00:00Z") });
  const snap = (p, min) => ({ [V]: { symbol: "V", address: V, priceUsd: p, at: new Date(Date.parse("2026-11-08T00:00:00Z") + min * 60000).toISOString() } });
  for (let i = 0; i < 4; i++) feed.appendSeries(snap(i + 1, i * 20));
  fs.appendFileSync(file, "{not json\n");
  feed.appendSeries(snap(9, 100));
  feed.appendSeries(snap(10, 120));
  const lines = fs.readFileSync(file, "utf8").split("\n").filter(Boolean);
  assert.ok(lines.length <= 5);
  assert.deepEqual(feed.readSeries(V).slice(-2), [9, 10]); // corrupt line skipped, the rest still read
  assert.equal(feed.appendSeries({ [V]: null }), 0);
});

test("poll cycle: stables get a peg check, VIRTUAL gets a trend and a Seykota score, missing tokens are null", async () => {
  const pairs = [pair(U, "0xo", { priceUsd: "0.999" }), pair(V, "0xo", { priceUsd: "0.54" })];
  const feed = createFeed({ fetchImpl: async () => json(pairs), sleep: async () => {}, seriesFile: tmp() });
  const out = await feed.pollWatchlist();
  assert.equal(out.USDC.pegDeviationBps, -10);
  assert.equal(out.VIRTUAL.trendScore, null); // not enough history yet
  assert.equal(out.VIRTUAL.seykotaScore, null);
  assert.equal(out.DAI, null);
});
