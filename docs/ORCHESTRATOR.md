# Swap Orchestrator

Combines a Seykota (trend) signal and a Druckenmiller (macro/fundamental) signal per asset, scores their agreement, and
plans a swap on Base. Handler: `swap-orchestrator-handler.ts`. Config and safety rules: `lib/`.

```
Seykota signals ─┐
                 ├─> alignment engine ─> policy (allowlist, caps) ─> swap plan ─> [execution: NOT WIRED]
Druckenmiller ───┘
```

## What is implemented, and what is not

| Part | State |
|---|---|
| Signal normalisation and alignment scoring | Implemented, tested |
| Safety policy (allowlist, per-swap and daily caps, request can only tighten limits) | Implemented, tested |
| Router and RPC configuration | Implemented, tested |
| Execution state machine (`lib/orchestrator-exec.js`): simulate before sign, failover only before broadcast, one broadcast, spend recorded first | Implemented, tested with fake adapters |
| Verified Base token table (USDC, WETH, cbBTC) | Implemented; symbol and decimals read on chain |
| **Concrete adapters** (`lib/orchestrator-live.js`): router quotes, signing from the CDP wallet, receipts | **Not written.** Returns `null`, so a live job fails closed |

An earlier version returned `EXECUTED` with a placeholder hash. That was removed so a buyer is never told a swap happened when none did.

## Going live: what is left

Live mode needs `ORCHESTRATOR_LIVE=true` **and** `createLiveAdapters` to return adapters. Each adapter set (one per router) supplies `quote`, `build`, `simulate`, `broadcast`, `confirm`; the state machine does the rest:

1. Re-clamp the amount to the per-swap ceiling and what is left of today's cap.
2. For each router in order (1 retry each, 8 s timeout): quote, build, simulate. A revert or error moves on to the next router. If all fail: abort, nothing spent.
3. Record the spend, then broadcast **once**. No failover after this point.
4. A broadcast error is an unknown outcome: `FAILED`, spend stays recorded, no retry.
5. Confirm the original hash: `EXECUTED`, `FAILED` (reverted) or `PENDING` (keep tracking that hash).

Selling a non-USDC token needs an explicit USD price from the adapters; a missing price is never assumed to be $1. Before pointing this at real funds, use a fresh burner wallet with a small balance (the same pattern as the dApp's faucet), keep the keys in the runtime environment only, and run the adapters against a fork or tiny amounts first.

## Routers (failover order)

Names are the contract names on the verified Basescan source (checked 2026-11-08). Re-verify before trusting a new address.

| Role | Address | Contract |
|---|---|---|
| primary | `0x111111125421cA6dc452d289314280a0f8842A65` | 1inch AggregationRouterV6 |
| fallback 1 | `0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE` | LI.FI LiFiDiamond |
| fallback 2 | `0x6fF5693b99212Da76ad316178A184AB56D299b43` | Uniswap UniversalRouter |

## RPC endpoints (failover order)

Defaults: `https://mainnet.base.org`, `https://base.drpc.org`, `https://base.api.pocket.network`. The earlier defaults
(`developer-access-mainnet.base.org`, `1rpc.io/base`) did not work. Override with `COINBASE_RPC`, `FALLBACK_RPC_1`, `FALLBACK_RPC_2`.
URLs can carry API keys, so only the host is ever written to a deliverable.

## Failover rule

Fail over to the next router only **before** a transaction is broadcast (quote, build, simulate). After broadcast, keep
tracking the original hash: building a new transaction through another router could swap twice.

## Safety policy

A job request is untrusted. The server's environment sets the limits:

| Variable | Default | Meaning |
|---|---|---|
| `ORCHESTRATOR_ALLOWED_ASSETS` | `ETH,WETH,CBBTC` | Only these may be traded |
| `ORCHESTRATOR_MAX_SWAP_PCT` | 10 | Ceiling, % of reported equity. A request can only lower it |
| `ORCHESTRATOR_MAX_SWAP_USD` | 100 | Absolute per-swap ceiling, whatever equity or balance a request reports |
| `ORCHESTRATOR_MIN_ALIGNMENT_SCORE` | 70 | Floor. A request can only raise it |
| `ORCHESTRATOR_DAILY_CAP_USD` | 250 | Total per UTC day (in memory; use durable storage before going live) |

ACP marketplace notes are parked in [ACP.md](ACP.md).

## Tests

`npm test` (Node 22.18+). Covers policy, config, the handler end to end, and a syntax check of every `.ts` file.

## Price feed (`lib/feeds/dexscreener.js`)

Free DexScreener data, no key. It supplies the inputs for the Seykota trend signal and the pre-trade checks. It is **not yet called by the handler**: the handler still takes signals from the request.

| Function | Purpose |
|---|---|
| `createFeed({...}).pollWatchlist()` | Snapshot the watchlist, append to the series, return per-token results |
| `bucketSeries`, `trendScore` | Trend from a **time-bucketed** series (15 minute buckets), so uneven polling does not distort it. `null` until 28 buckets exist |
| `trendToSeykotaScore` | Maps the 0 to 100 trend onto the handler's -7..+7 scale. No data gives no signal (`null`) |
| `pegDeviationBps` | For USDC, USDT, DAI and USDbC only (CADC and EURC track other currencies) |
| `checkLiquidity` | Floor ($100k default) and trade share of the pool (1% default). Unknown liquidity means no |
| `priceAgreement` | The router quote must be within a tolerance (100 bps) of the feed price. The feed is a hint, never the trade price |

Notes: a token may sit on either side of a pair (the quote-side price is derived). The price series is kept **in memory** (capped at 20,000 rows) and resets on restart, so the trend score is `null` again until enough history has built up. To persist it, set `PRICE_SERIES_FILE` (JSONL; a corrupt line is skipped rather than discarding the file; on an ephemeral runtime it needs a persistent path). Requests send an honest `User-Agent`. All seven watchlist addresses were read on chain (symbol and decimals) before being listed.

## DefiLlama (`lib/feeds/defillama.js`)

A second, independent source. Also not yet called by the handler.

- **`crossCheck({ dexscreener, defillama, ... })`** fails closed: fewer than two usable prices, or a spread over 1%, means do not size a swap. (The original `spreadPct` returned `null` for one price, which a caller could read as fine.)
- **`getPrices`** flags `stale` (older than 30 minutes) and `lowConfidence` (under 0.9) instead of passing them through as good.
- **`scanStableYields`** is information only: it never moves funds. Defaults: Base, USD stables only (a symbol allowlist, because DefiLlama's own `stablecoin` flag also covers EUR and CAD pegs), TVL at least $100k, APY at most 50%, outliers removed. Each row carries `risks` (reward-driven, predicted-down, impermanent-loss, multi-asset). `apyBaseOnly` is the yield without incentive tokens.
- Why those filters: a plain "top stable APY" scan of live data was led by a 447% pool paid entirely in rewards, and several rows DefiLlama itself marks as outliers.
- The `/pools` payload covers about 15,000 pools, so it is fetched once per 10 minutes, shared between callers, and only Base rows are kept.

## Failover numbers

Settings in `FAILOVER_POLICY` (`lib/orchestrator-config.js`). Live execution is not wired, so nothing retries yet; these are the limits to use when it is.

| | Value |
|---|---|
| Retries per router | 1 |
| Router timeout | 8000 ms |
| Max slippage | 100 bps (a request can only tighten it: `clampSlippageBps`) |
| RPC health check | every 30 s, timeout 5000 ms, unhealthy after 2 consecutive failures |
| Every router or RPC failed | abort and alert (never trade) |
