// DefiLlama for the swap orchestrator on Base. Two jobs:
//   1) Prices: a referee spot price (coins.llama.fi) to cross-check DexScreener before sizing a swap.
//   2) Yields: where USD stablecoins earn on Base (yields.llama.fi), with risk flags. Information only: nothing here
//      moves funds, and the orchestrator's asset allowlist and caps are unaffected.
//
// Zero dependencies, Node 18+, no API key. Network and clock are injectable (createLlama), so tests run offline.
// The yields payload covers every pool on every chain (about 15,000 pools), so it is fetched at most once per TTL,
// shared between concurrent callers, and only the Base rows are kept in memory.

import { WATCHLIST } from "./dexscreener.js";

const ADDRESS_RE = /^0x[0-9a-fA-F]{40}$/;
const PERIOD_RE = /^\d{1,3}[mhdw]$/;
const num = (v) => {
  if (v === null || v === undefined || v === "") return null; // Number(null) is 0: a missing value must stay missing
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
};

// Conservative allowlist of USD stablecoin symbols. DefiLlama's own `stablecoin` flag also includes EUR, CAD and other
// pegs (for example JEUR), which are not USD stables, so a symbol allowlist is applied on top.
export const USD_STABLE_SYMBOLS = new Set([
  "USDC", "USDT", "DAI", "USDBC", "USDS", "SUSDS", "GHO", "LUSD", "FRAX", "CRVUSD", "USDE", "SUSDE", "AUSD", "DOLA", "PYUSD",
]);

// ── Pure helpers ─────────────────────────────────────────────────────────────
/**
 * Compare price sources. Fails CLOSED: fewer than two usable prices means we cannot cross-check, which is not "fine".
 * sources: { dexscreener: 0.54, defillama: 0.541, ... } (null or 0 = missing)
 */
export function crossCheck(sources, { maxSpreadPct = 1, minSources = 2 } = {}) {
  const used = Object.entries(sources).filter(([, p]) => Number.isFinite(p) && p > 0);
  if (used.length < minSources) return { ok: false, spreadPct: null, reason: `only ${used.length} usable price source(s); need ${minSources}` };
  const vals = used.map(([, p]) => p);
  const hi = Math.max(...vals);
  const lo = Math.min(...vals);
  const spreadPct = ((hi - lo) / ((hi + lo) / 2)) * 100;
  return spreadPct <= maxSpreadPct
    ? { ok: true, spreadPct, reason: null }
    : { ok: false, spreadPct, reason: `sources disagree by ${spreadPct.toFixed(2)}% (limit ${maxSpreadPct}%)` };
}

/** Same as crossCheck but only the spread, null if fewer than two prices (the caller must treat null as NOT ok). */
export function spreadPct(prices) {
  return crossCheck(Object.fromEntries(prices.map((p, i) => [i, p])), { maxSpreadPct: Infinity }).spreadPct;
}

export function toYield(p) {
  const apy = num(p.apy);
  const apyReward = num(p.apyReward);
  const apyBase = num(p.apyBase);
  return {
    poolId: p.pool,
    project: p.project,
    chain: p.chain,
    symbol: p.symbol,
    tvlUsd: num(p.tvlUsd),
    apy,
    apyBase,
    apyReward,
    // Yield that does not depend on incentive tokens (fees or lending interest). Falls back to total minus rewards.
    apyBaseOnly: apyBase ?? (apy != null ? Math.max(0, apy - (apyReward || 0)) : null),
    rewardShare: apy > 0 && apyReward != null ? Math.min(1, apyReward / apy) : 0,
    stablecoin: p.stablecoin === true,
    ilRisk: p.ilRisk ?? null,
    exposure: p.exposure ?? null,
    outlier: p.outlier === true,
    predictedDown: p.predictions?.predictedClass === "Down",
    url: p.url ?? null,
  };
}

/** Reasons not to chase a yield. The scan filters the worst; the rest are shown so a reader can judge. */
export function riskFlags(y) {
  const flags = [];
  if (y.outlier) flags.push("outlier");
  if (y.rewardShare > 0.5) flags.push("reward-driven");
  if (y.predictedDown) flags.push("predicted-down");
  if (y.ilRisk === "yes") flags.push("impermanent-loss");
  if (y.exposure === "multi") flags.push("multi-asset");
  if (y.apy > 100) flags.push("implausible-apy");
  return flags;
}

const isUsdStable = (symbol) => {
  const parts = String(symbol || "").toUpperCase().split(/[-/\s+]+/).filter(Boolean);
  return parts.length > 0 && parts.every((s) => USD_STABLE_SYMBOLS.has(s));
};

/** USD-stable pools above a TVL floor, outliers and implausible APYs removed, best APY first, with risk flags. */
export function filterStableYields(rows, { minTvl = 100_000, maxApy = 50, limit = 15, usdOnly = true } = {}) {
  return rows
    .filter((y) => y.stablecoin && (!usdOnly || isUsdStable(y.symbol)))
    .filter((y) => (y.tvlUsd || 0) >= minTvl && y.apy != null && y.apy <= maxApy && !y.outlier)
    .sort((a, b) => b.apy - a.apy)
    .slice(0, limit)
    .map((y) => ({ ...y, risks: riskFlags(y) }));
}

// ── Feed (network, clock injectable) ─────────────────────────────────────────
export function createLlama({
  fetchImpl = globalThis.fetch,
  now = () => Date.now(),
  coinsUrl = process.env.DEFILLAMA_COINS_BASE || "https://coins.llama.fi",
  yieldsUrl = process.env.DEFILLAMA_YIELDS_BASE || "https://yields.llama.fi",
  chainId = "base",
  chainName = "Base",
  yieldsTtlMs = 10 * 60 * 1000,
  maxPriceAgeMs = 30 * 60 * 1000,
  minConfidence = 0.9,
  timeoutMs = 15000,
} = {}) {
  async function get(url) {
    const res = await fetchImpl(url, { headers: { "User-Agent": "bushido-virtuals/1.0 (price feed)" }, signal: AbortSignal.timeout(timeoutMs) });
    if (!res.ok) throw new Error(`DefiLlama ${res.status} on ${new URL(url).pathname.split("/").slice(0, 3).join("/")}`);
    return res.json();
  }
  const key = (a) => {
    if (!ADDRESS_RE.test(a)) throw new Error(`Not a token address: ${String(a).slice(0, 20)}`);
    return `${chainId}:${a}`;
  };

  /** { [address as given]: { price, symbol, confidence, at, stale, lowConfidence } | null }. Stale or low-confidence prices are flagged. */
  async function getPrices(addresses) {
    const list = addresses.map((a) => [a, key(a)]);
    const data = await get(`${coinsUrl}/prices/current/${list.map(([, k]) => k).join(",")}`);
    const byKey = new Map(Object.entries(data.coins || {}).map(([k, v]) => [k.toLowerCase(), v]));
    const out = {};
    for (const [addr, k] of list) {
      const v = byKey.get(k.toLowerCase());
      const price = num(v?.price);
      if (!v || !(price > 0)) {
        out[addr] = null;
        continue;
      }
      const atMs = v.timestamp ? v.timestamp * 1000 : null;
      const confidence = num(v.confidence);
      out[addr] = {
        price,
        symbol: v.symbol,
        confidence,
        at: atMs ? new Date(atMs).toISOString() : null,
        stale: atMs == null || now() - atMs > maxPriceAgeMs,
        lowConfidence: confidence != null && confidence < minConfidence,
      };
    }
    return out;
  }

  /** Daily (or other) price points for EMA warm-up. span is capped at 500 and the period format is checked. */
  async function getPriceHistory(address, { span = 60, period = "1d" } = {}) {
    if (!PERIOD_RE.test(period)) throw new Error("Bad period (use for example 1d, 4h, 30m)");
    const n = Math.max(1, Math.min(500, Math.floor(Number(span)) || 60));
    const k = key(address);
    const data = await get(`${coinsUrl}/chart/${k}?span=${n}&period=${period}`);
    const entry = Object.entries(data.coins || {}).find(([kk]) => kk.toLowerCase() === k.toLowerCase())?.[1];
    return (entry?.prices || [])
      .filter((p) => num(p.price) > 0)
      .map((p) => ({ t: p.timestamp * 1000, at: new Date(p.timestamp * 1000).toISOString(), price: p.price }));
  }

  // Yields: Base rows only are kept; concurrent callers share one request.
  let cache = { at: 0, rows: null };
  let inflight = null;
  async function baseRows() {
    if (cache.rows && now() - cache.at < yieldsTtlMs) return cache.rows;
    if (!inflight) {
      inflight = get(`${yieldsUrl}/pools`)
        .then((d) => {
          cache = { at: now(), rows: (d.data || []).filter((p) => p.chain === chainName).map(toYield) };
          return cache.rows;
        })
        .finally(() => {
          inflight = null;
        });
    }
    return inflight;
  }

  const scanStableYields = async (opts) => filterStableYields(await baseRows(), opts);

  /** Best yields for a symbol (exact token match, not a substring), outliers removed. */
  async function bestYieldsFor(symbol, { minTvl = 10_000, limit = 5, maxApy = 50 } = {}) {
    const want = String(symbol).toUpperCase();
    return (await baseRows())
      .filter((y) => String(y.symbol || "").toUpperCase().split(/[-/\s+]+/).includes(want))
      .filter((y) => (y.tvlUsd || 0) >= minTvl && y.apy != null && y.apy <= maxApy && !y.outlier)
      .sort((a, b) => b.apy - a.apy)
      .slice(0, limit)
      .map((y) => ({ ...y, risks: riskFlags(y) }));
  }

  return { getPrices, getPriceHistory, scanStableYields, bestYieldsFor, watchlist: WATCHLIST };
}
