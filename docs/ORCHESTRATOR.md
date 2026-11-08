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
| **Live execution through a CDP wallet** | **Not implemented.** A live job returns `FAILED` ("not implemented"); only `dry_run: true` produces a plan. |

An earlier version returned `EXECUTED` with a placeholder hash. That was removed so a buyer is never told a swap happened when none did.

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

## Using it in an ACP runtime

Copy the handler together with `lib/` into the offering folder. The `../../../runtime/offeringTypes.js` import is type-only
and is erased at run time. Node 22.18+ runs the `.ts` file directly.

A reasonable first offering is **signals only** (`dry_run: true`): it sells the alignment analysis without holding keys.

## Tests

`npm test` (Node 22.18+). Covers policy, config, the handler end to end, and a syntax check of every `.ts` file.
