// DexScreener price feed for the swap orchestrator on Base: snapshots, a time-bucketed price series, a trend score
// in the Seykota -7..+7 scale, a peg check for USD stablecoins, and pre-trade liquidity and price-agreement checks.
//
// Zero dependencies, Node 18+ (global fetch), no API key. Everything that touches the network or the clock is
// injectable (createFeed), so the tests run offline.
//
// DexScreener returns SNAPSHOTS, not candles, so every poll is appended to a series and trends are computed from that.
// Treat its numbers as a hint, never as the trade price: thin-pool liquidity can be faked. Confirm with the router
// quote before trading (priceAgreement below).

import fs from "node:fs";
import path from "node:path";

const CHAIN = "base";
const ADDRESS_RE = /^0x[0-9a-fA-F]{40}$/;

// Verified on Base on 2026-11-08 by reading symbol() and decimals() from each contract. Do not add an address from
// memory: read the token on chain first.
export const WATCHLIST = {
  USDC: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
  USDT: "0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2",
  DAI: "0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb",
  CADC: "0x043eB4B75d0805c43D7C834902E335621983Cf03",
  USDBC: "0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA",
  EURC: "0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42",
  VIRTUAL: "0x0b3e328455c4059EEb9e3f84b5543F74E24e7E1b",
};
// Stablecoins pegged to 1 USD (CADC and EURC track other currencies, so a $1 peg check does not apply to them).
export const USD_STABLES = new Set(["USDC", "USDT", "DAI", "USDBC"]);

const num = (v) => {
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
};

// ── Pair selection ───────────────────────────────────────────────────────────
// A token can be either side of a pair. Take the deepest-liquidity pair that contains it and express the price of THE
// TOKEN in USD (for the quote side: base USD price / base price in quote units).
export function pickBestPair(pairs, tokenAddress) {
  const t = String(tokenAddress).toLowerCase();
  const mine = (Array.isArray(pairs) ? pairs : []).filter(
    (p) => p?.baseToken?.address?.toLowerCase() === t || p?.quoteToken?.address?.toLowerCase() === t
  );
  if (!mine.length) return null;
  mine.sort((a, b) => (num(b.liquidity?.usd) || 0) - (num(a.liquidity?.usd) || 0));
  return mine[0];
}

export function toSnapshot(pair, tokenAddress, at = new Date().toISOString()) {
  if (!pair) return null;
  const isBase = pair.baseToken.address.toLowerCase() === String(tokenAddress).toLowerCase();
  const tok = isBase ? pair.baseToken : pair.quoteToken;
  const other = isBase ? pair.quoteToken : pair.baseToken;
  const baseUsd = num(pair.priceUsd);
  const native = num(pair.priceNative);
  const priceUsd = isBase ? baseUsd : baseUsd != null && native > 0 ? baseUsd / native : null;
  return {
    symbol: tok.symbol,
    address: tok.address,
    otherSymbol: other?.symbol ?? null,
    pairAddress: pair.pairAddress,
    dex: pair.dexId,
    priceUsd,
    change: isBase ? pair.priceChange || {} : {}, // % change is for the base token only
    volume24h: num(pair.volume?.h24),
    buys24h: pair.txns?.h24?.buys ?? null,
    sells24h: pair.txns?.h24?.sells ?? null,
    liquidityUsd: num(pair.liquidity?.usd),
    fdv: num(pair.fdv),
    at,
  };
}

// ── Series math (pure) ───────────────────────────────────────────────────────
/** Last price in each time bucket, oldest first. Polling that is uneven in time no longer distorts the EMAs. */
export function bucketSeries(rows, bucketMs, nowMs = Date.now(), maxBuckets = 200) {
  const last = new Map();
  for (const r of rows) {
    const t = Date.parse(r.at);
    if (!Number.isFinite(t) || !(r.priceUsd > 0) || t > nowMs) continue;
    last.set(Math.floor(t / bucketMs), r.priceUsd); // rows are in time order, so the last one wins
  }
  return [...last.entries()].sort((a, b) => a[0] - b[0]).slice(-maxBuckets).map(([, p]) => p);
}

export function ema(values, period) {
  if (!values.length) return null;
  const k = 2 / (period + 1);
  let e = values[0];
  for (let i = 1; i < values.length; i++) e = values[i] * k + e * (1 - k);
  return e;
}

/** 0..100 from fast/slow EMA alignment. 50 = no trend; null until slowPeriod + 2 buckets exist. */
export function trendScore(values, fastPeriod = 12, slowPeriod = 26) {
  if (!values || values.length < slowPeriod + 2) return null;
  const window = values.slice(-(slowPeriod * 3));
  const fast = ema(window, fastPeriod);
  const slow = ema(window, slowPeriod);
  const price = values[values.length - 1];
  if (fast == null || slow == null || slow === 0) return null;
  const raw = 50 + ((fast - slow) / slow) * 100 * 10 + ((price - slow) / slow) * 100 * 5;
  return Math.max(0, Math.min(100, Math.round(raw)));
}

/** Map the 0..100 trend score onto the Seykota -7..+7 score the orchestrator takes. null stays null (no data, no signal). */
export function trendToSeykotaScore(score) {
  if (score == null || !Number.isFinite(score)) return null;
  const clamped = Math.max(0, Math.min(100, score));
  return Math.round(((clamped - 50) / 50) * 7 * 10) / 10;
}

/** Deviation from $1 in basis points (positive = above peg). null if there is no price. */
export function pegDeviationBps(snapshot, pegUsd = 1) {
  if (!snapshot || !(snapshot.priceUsd > 0)) return null;
  return Math.round(((snapshot.priceUsd - pegUsd) / pegUsd) * 10000);
}

// ── Pre-trade checks (pure) ──────────────────────────────────────────────────
/**
 * Is the pool deep enough for this trade? A floor on liquidity, plus the trade must be a small share of the pool.
 * Returns { ok, reasons[] } so a rejection can say why.
 */
export function checkLiquidity(snapshot, { tradeUsd, minLiquidityUsd = 100_000, maxTradePct = 1 } = {}) {
  const reasons = [];
  if (!snapshot) return { ok: false, reasons: ["no snapshot (no pair found)"] };
  const liq = snapshot.liquidityUsd;
  if (!(liq > 0)) reasons.push("liquidity unknown");
  else {
    if (liq < minLiquidityUsd) reasons.push(`liquidity $${Math.round(liq)} is below the $${minLiquidityUsd} floor`);
    if (tradeUsd > 0 && (tradeUsd / liq) * 100 > maxTradePct) reasons.push(`trade is more than ${maxTradePct}% of the pool`);
  }
  return { ok: reasons.length === 0, reasons };
}

/** Does the router quote agree with the feed price? A feed hint is never the trade price. */
export function priceAgreement(feedPriceUsd, quotePriceUsd, maxBps = 100) {
  if (!(feedPriceUsd > 0) || !(quotePriceUsd > 0)) return { ok: false, diffBps: null };
  const diffBps = Math.round((Math.abs(quotePriceUsd - feedPriceUsd) / feedPriceUsd) * 10000);
  return { ok: diffBps <= maxBps, diffBps };
}

// ── Feed (network, clock and disk are injectable) ────────────────────────────
export function createFeed({
  fetchImpl = globalThis.fetch,
  sleep = (ms) => new Promise((r) => setTimeout(r, ms)),
  now = () => Date.now(),
  baseUrl = process.env.DEXSCREENER_API_BASE || "https://api.dexscreener.com",
  seriesFile = process.env.PRICE_SERIES_FILE || path.join(process.cwd(), "data", "price-series.jsonl"),
  maxSeriesLines = 20000,
  bucketMs = 15 * 60 * 1000,
  minGapMs = 250,
  timeoutMs = 8000,
} = {}) {
  let lastCallAt = 0;

  async function get(pathname, attempt = 0) {
    const wait = minGapMs - (now() - lastCallAt);
    if (wait > 0) await sleep(wait);
    lastCallAt = now();
    const res = await fetchImpl(`${baseUrl}${pathname}`, {
      headers: { "User-Agent": "bushido-virtuals/1.0 (price feed)" },
      signal: AbortSignal.timeout(timeoutMs),
    });
    if (res.status === 429 && attempt < 2) {
      await sleep(1500 * (attempt + 1));
      return get(pathname, attempt + 1);
    }
    if (!res.ok) throw new Error(`DexScreener ${res.status} on ${pathname.split("?")[0]}`);
    return res.json();
  }
  const pairsOf = (data) => (Array.isArray(data) ? data : data?.pairs || []);
  const checkAddr = (a) => {
    if (!ADDRESS_RE.test(a)) throw new Error(`Not a token address: ${String(a).slice(0, 20)}`);
    return a;
  };

  /** Up to 30 tokens per request. Missing tokens come back as null. */
  async function getSnapshots(addresses, chain = CHAIN) {
    const out = {};
    const list = addresses.map(checkAddr);
    for (let i = 0; i < list.length; i += 30) {
      const chunk = list.slice(i, i + 30);
      const pairs = pairsOf(await get(`/tokens/v1/${chain}/${chunk.join(",")}`));
      const at = new Date(now()).toISOString();
      for (const addr of chunk) out[addr] = toSnapshot(pickBestPair(pairs, addr), addr, at);
    }
    return out;
  }

  async function getTokenSnapshot(address, chain = CHAIN) {
    checkAddr(address);
    return toSnapshot(pickBestPair(pairsOf(await get(`/token-pairs/v1/${chain}/${address}`)), address), address, new Date(now()).toISOString());
  }

  // ── series on disk (JSONL), bounded, tolerant of a corrupt line ──
  function appendSeries(snapshots) {
    const lines = Object.values(snapshots)
      .filter((s) => s && s.priceUsd > 0)
      .map((s) => JSON.stringify({ at: s.at, symbol: s.symbol, address: s.address, priceUsd: s.priceUsd }));
    if (!lines.length) return 0;
    fs.mkdirSync(path.dirname(seriesFile), { recursive: true });
    fs.appendFileSync(seriesFile, lines.join("\n") + "\n");
    const all = fs.readFileSync(seriesFile, "utf8").split("\n").filter(Boolean);
    if (all.length > maxSeriesLines) fs.writeFileSync(seriesFile, all.slice(-maxSeriesLines).join("\n") + "\n");
    return lines.length;
  }

  function readRows(address) {
    let text;
    try {
      text = fs.readFileSync(seriesFile, "utf8");
    } catch {
      return [];
    }
    const rows = [];
    for (const l of text.split("\n")) {
      if (!l) continue;
      try {
        const r = JSON.parse(l);
        if (r.address?.toLowerCase() === address.toLowerCase()) rows.push(r);
      } catch {
        /* skip a corrupt line, keep the rest */
      }
    }
    return rows;
  }

  const readSeries = (address) => bucketSeries(readRows(address), bucketMs, now());

  /** One cycle: poll the watchlist, log the series. Stables get a peg check, others a trend score and Seykota score. */
  async function pollWatchlist() {
    const byAddr = await getSnapshots(Object.values(WATCHLIST));
    appendSeries(byAddr);
    const result = {};
    for (const [symbol, addr] of Object.entries(WATCHLIST)) {
      const snap = byAddr[addr];
      if (!snap) {
        result[symbol] = null;
        continue;
      }
      if (USD_STABLES.has(symbol)) result[symbol] = { ...snap, pegDeviationBps: pegDeviationBps(snap) };
      else {
        const trend = trendScore(readSeries(addr));
        result[symbol] = { ...snap, trendScore: trend, seykotaScore: trendToSeykotaScore(trend) };
      }
    }
    return result;
  }

  return { getSnapshots, getTokenSnapshot, appendSeries, readSeries, pollWatchlist, seriesFile };
}
