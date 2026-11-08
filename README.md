# bushido-virtuals

Job handlers and supporting material for the Bushido trading agents: a Seykota-style trend agent, a Druckenmiller-style
macro agent, market trackers, and a swap orchestrator that combines the two agents' signals into a capped swap plan.

> **Status in one paragraph.** The swap orchestrator is the only part with a safety layer and tests (`lib/`, `test/`,
> 61 tests, CI). The execution state machine is built and tested with fake adapters, but the **concrete adapters (router quotes, wallet
> signing) are not written**, so a live job still fails closed and only a **dry-run plan** is produced. The other handlers are market-data and persona jobs kept as they were written; they
> parse (checked in CI) but their data sources have not been exercised here. Anything that moves money, such as the
> dip-buy and micro-swap examples, is reference material, not a finished product.

## Contents

- [Quick start](#quick-start)
- [How the pieces fit](#how-the-pieces-fit)
- [Swap orchestrator](#swap-orchestrator)
- [The other handlers](#the-other-handlers)
- [Examples and reference material](#examples-and-reference-material)
- [Configuration](#configuration)
- [Tests and CI](#tests-and-ci)
- [Repository map](#repository-map)
- [What is and is not verified](#what-is-and-is-not-verified)
- [Roadmap](#roadmap)

## Quick start

Requires **Node 22.18 or newer**. No dependencies to install: Node strips the TypeScript types itself.

```bash
npm test                                  # 61 tests, offline, a few seconds
node --input-type=module -e '
  const { executeJob } = await import("./swap-orchestrator-handler.ts");
  const out = await executeJob({
    seykota_signals: [{ asset: "ETH", score: 7, action: "LONG" }],
    druckenmiller_signals: [{ asset: "ETH", fundamental_signal: "STRONG_BUY", action: "ADD", reward_risk_ratio: 5.2, conviction: 8 }],
    portfolio: { equity_usd: 10000, usdc_balance: 2500 },
    dry_run: true
  });
  console.log(JSON.stringify(JSON.parse(out.deliverable), null, 2));
'
```

That prints an alignment score for ETH and one `DRY_RUN` swap plan of at most $100 (see the limits below). Nothing is sent
anywhere.

## How the pieces fit

```
Seykota signals ─────┐
(trend: score -7..7) │
                     ├─> alignment engine ─> safety policy ─> swap plan ─> execution
Druckenmiller ───────┘   (do both agents      (allowlist,      (amounts,    NOT WIRED
(macro: buy/sell,         agree? how strongly?) caps, floors)    routers)     (fails closed)
 conviction, R/R)
```

Every handler exports one function, `executeJob(request)`, and returns `{ deliverable: string }` where the deliverable is
JSON. That shape comes from the Virtuals ACP job format; the type import (`../../../runtime/offeringTypes.js`) is erased
when Node runs the file, so the handlers run standalone. How to plug them into a runtime is parked in
[docs/ACP.md](docs/ACP.md).

## Swap orchestrator

File: [`swap-orchestrator-handler.ts`](swap-orchestrator-handler.ts). Full notes: [docs/ORCHESTRATOR.md](docs/ORCHESTRATOR.md).

**Request** (all fields optional except the signals):

| Field | Meaning |
|---|---|
| `seykota_signals[]` | `{ asset, score (-7..7), action: LONG/SHORT/CLOSE/HOLD }` |
| `druckenmiller_signals[]` | `{ asset, fundamental_signal: STRONG_BUY/BUY/HOLD/SELL/STRONG_SELL, action: ADD/HOLD/TRIM/EXIT_NOW, reward_risk_ratio, conviction (1-10) }` |
| `portfolio` | `{ equity_usd, usdc_balance, existing_positions: { ETH: { size_usd } } }` |
| `min_alignment_score` | Alignment bar. **Can only raise** the server floor |
| `max_swap_pct` | Swap size as % of equity. **Can only lower** the server ceiling |
| `dry_run` | `true` returns plans only |

**Alignment.** Both agents must agree on direction. Disagreement or a missing signal is `NO_TRADE`. A `CLOSE` from either
agent wins (risk management overrides the upside thesis). Agreement scores 50 plus trend strength (up to 25), conviction
(up to 15) and reward/risk (up to 10, with a penalty under 2:1), out of 100.

**Statuses** in `swap_plans[]`: `DRY_RUN`, `ABORTED_NO_ALIGNMENT` (below the bar, or the amount fell to $0),
`REJECTED` (asset not on the allowlist), `FAILED`, `PENDING` (broadcast, not yet confirmed), `EXECUTED` (confirmed on chain). Live runs return `FAILED` today: no adapters.

### Safety policy

A job request is untrusted input. The server's environment sets the limits, and a request can only be stricter:
[`lib/orchestrator-policy.js`](lib/orchestrator-policy.js).

| Rule | Default | Request may |
|---|---|---|
| Tradable assets | `ETH`, `WETH`, `CBBTC` | not add any |
| Max swap as % of equity | 10 | lower it |
| Max swap in USD (absolute) | 100 | not change it |
| Daily total | 250 USD per UTC day | not change it |
| Alignment floor | 70 | raise it |
| Slippage ceiling | 100 bps | tighten it |

Equity and balances in a request are only a sizing hint, because the buyer supplies them; the absolute caps hold whatever
they report. Bad numbers (negative, NaN, strings) count as zero or fall back to the defaults. The daily cap is in memory
and resets on restart: use durable storage before any live use.

### Routers, RPCs and failover

[`lib/orchestrator-config.js`](lib/orchestrator-config.js). Routers on Base (chain 8453), in failover order, named from
the verified Basescan source (checked 2026-11-08):

| Role | Contract |
|---|---|
| primary | 1inch AggregationRouterV6 |
| fallback 1 | LI.FI LiFiDiamond |
| fallback 2 | Uniswap UniversalRouter |

Default RPCs: `mainnet.base.org`, `base.drpc.org`, `base.api.pocket.network` (all answered `eth_chainId` = 8453 when
tested). Two older defaults were dropped: `developer-access-mainnet.base.org` no longer answers and `1rpc.io/base`
returned a usage-limit error. RPC URLs can carry API keys, so only the host is ever written to a deliverable.

Failover numbers: 1 retry per router, 8 s timeout, RPC health check every 30 s and unhealthy after 2 consecutive
failures; if everything fails, abort and alert. **Failover is only allowed before a transaction is broadcast**
(`canFailOver`): after broadcast, building a new transaction through another router could swap twice, so keep tracking the
original hash instead. These numbers are settings; nothing retries yet because there is no live execution.

## The other handlers

All are `executeJob(request)` jobs with the cron schedule noted in their header. They share the Seykota/Druckenmiller
theme: data jobs feed the trend agent, soul jobs hold each agent's rules.

| File | Job | Cron in header | Needs |
|---|---|---|---|
| `bushido-soul-handler-5.ts` | Bushido Soul: the agent's daily self-evaluation against the seven virtues | daily 00:00 | none |
| `druckenmiller-soul-handler-2.ts` | Druckenmiller Soul: macro principles, regimes, sizing rules | daily 06:00 | none |
| `suggestions-handler-3.ts` | Trading/farming suggestions from vol, funding, LP health, TVL | every 4 h | `COINGECKO_API_KEY` |
| `tracking-coin-handler-3.ts` | Per-coin price, momentum, trend score, vol metrics | every 30 min | `COINGECKO_API_KEY` |
| `tracking-volume-handler-3.ts` | Volume across tokens, DEXes and chains | every 15 min | `COINGECKO_API_KEY` |
| `tracking-chain-handler-4.ts` | Chain TVL, momentum, DEX volume, stablecoin and bridge flows | every 4 h | see file |
| `tracking-cross-chain-handler-2.ts` | Capital flow between chains; which are absorbing or losing | every 3 h | see file |
| `tracking-fraxtal-volume-handler-2.ts` | Fraxtal-specific DEX, bridge, FRAX peg and lending volume | every 20 min | see file |

`druckenmiller-soul-handler.ts` is a byte-for-byte duplicate of `-2`, and `NODLE_SETUP.md` / `NODLE_SETUP-1.md` and the two
`VIRTUALS…DIP_BUY_COMPLETE.txt` copies are near-duplicates left as received. They can be cleaned up when you decide which to keep.

## Examples and reference material

Kept for reference; none of it is wired into the tested path.

- **Dip-buy job** (`virtuals-dip-buy.js`, `virtuals-dip-buy.config.ts`, `examples/virtuals-dip-buy.scheduler.example.ts`,
  `ARCHITECTURE.md`, `SETUP_GUIDE.md`, `test-setup.js`): hourly check that buys $0.025 of VIRTUALS after a drop of 4% or
  more in 12 hours. `test-setup.js` is its setup validator (needs `dotenv`; not part of `npm test`).
- **Micro-swap agent** (`NODLE_SETUP*.md`, `nodle-3x-daily-micro*.json`, `nodle-backend-example.js`): a small scheduled
  swap through a CDP backend. The example server uses an SDK import I have not checked against the current CDP package.
- **UI mock-ups** (`*.jsx`, `bushido_trading_dashboard.tsx.txt`): React views of the souls and the cron dashboard. They
  are design sketches with sample data, not a running dashboard.
- **Contracts** (`BushidoBased_Zora_v2.sol`, `ERC1155Faucet.sol`): Solidity drafts for a Zora-coin burn-to-mint token and
  an ERC-1155 faucet. **Unaudited and undeployed from here.** Do not deploy without an audit.
- **CoinGecko API notes** (`core.md`, `coins` references: `categories.md`, `coin-history.md`, `contract.md`,
  `treasury.md`, `utils.md`): endpoint cheat-sheets used when writing the tracker handlers.
- `all_handlers_bash.sh`: a script that recreates the handler files; superseded by the files themselves.
- `1stgen|arc/`: an archived first-generation README.

## Configuration

Everything is read from the environment; nothing is read from a request.

| Variable | Used by | Default |
|---|---|---|
| `ORCHESTRATOR_ALLOWED_ASSETS` | allowlist, comma separated | `ETH,WETH,CBBTC` |
| `ORCHESTRATOR_MAX_SWAP_PCT` | % of equity ceiling (max 100) | `10` |
| `ORCHESTRATOR_MAX_SWAP_USD` | absolute per-swap ceiling | `100` |
| `ORCHESTRATOR_MIN_ALIGNMENT_SCORE` | alignment floor | `70` |
| `ORCHESTRATOR_DAILY_CAP_USD` | daily total | `250` |
| `COINBASE_RPC`, `FALLBACK_RPC_1`, `FALLBACK_RPC_2` | Base RPC overrides | see above |
| `COINGECKO_API_KEY` | market-data handlers | none |
| `ORCHESTRATOR_LIVE` | must be `true` to attempt live execution | off |
| `CDP_API_KEY_NAME`, `CDP_API_KEY_PRIVATE_KEY`, `CDP_WALLET_ID` | future live execution | none |

Keep keys in the environment of whatever runs the jobs. Never commit them, and never put a key in an RPC URL that you log.
`.env` files are in `.gitignore`.

## Tests and CI

```bash
npm test      # node --test "test/*.test.js"
```

Use that script rather than a bare `node --test`: the root `test-setup.js` matches Node's default test pattern and is not
a test. GitHub Actions runs the same command on Node 22 for every push and pull request.

| File | Covers |
|---|---|
| `test/policy.test.js` | allowlist, clamps (a request can only tighten), daily cap and UTC rollover, failover stages |
| `test/config.test.js` | router order and identities, RPC defaults and overrides, host-only logging, failover numbers |
| `test/exec.test.js` | the execution state machine with fake adapters: simulate-before-sign, failover only before broadcast, one broadcast, cap enforced and recorded first, unknown outcomes |
| `test/feed.test.js` | the DexScreener feed with a fake `fetch`: pair choice, either token side, time-bucketed series, trend and Seykota mapping, peg, liquidity and price-agreement checks |
| `test/orchestrator.test.js` | the handler end to end: hostile requests stay inside the caps, unlisted assets are rejected, live mode fails closed |
| `test/syntax.test.js` | every root and `examples/` `.ts` file parses. A cron comment like `*/15` inside a block comment once broke eight files |

## Repository map

```
swap-orchestrator-handler.ts     the orchestrator
lib/orchestrator-config.js       routers, RPCs, failover numbers, host-only logging
lib/orchestrator-policy.js       limits, clamps, daily cap, failover rule
lib/orchestrator-exec.js         execution state machine (adapters injected)
lib/feeds/dexscreener.js         price feed, trend score, peg and liquidity checks (not yet wired into the handler)
lib/orchestrator-live.js         concrete adapters: not written yet (returns null)
*-handler-*.ts                   the other jobs (table above)
examples/                        integration examples that are not handlers
test/                            node:test suites
docs/ORCHESTRATOR.md             orchestrator detail
docs/ACP.md                      ACP runtime notes (parked)
.github/workflows/test.yml       CI
```

## What is and is not verified

Verified: the tests above; that all 22 TypeScript sources parse; that the three default RPCs answer for chain 8453 (at
the time of checking); that the router names match the verified Basescan source.

Not verified: any live trade; the CDP SDK calls; the data sources behind the tracker handlers; the `.sol` contracts; the
`TENDERLY_WSS` endpoint from earlier notes (left out); the dip-buy and micro-swap examples.

## Roadmap

1. Write the concrete adapters in `lib/orchestrator-live.js` (quotes per router, CDP signing, receipts) and try them on a fork and then with tiny amounts. The state machine around them is done.
2. Durable storage for the daily cap.
3. Pick one copy of each duplicate file and archive the rest.
4. Plug the handlers into an ACP runtime ([docs/ACP.md](docs/ACP.md)); start with a signals-only offering.

## License

MIT. See [LICENSE](LICENSE).
