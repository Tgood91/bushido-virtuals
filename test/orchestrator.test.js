import test from "node:test";
import assert from "node:assert/strict";

const { executeJob } = await import("../swap-orchestrator-handler.js");

const strong = (asset = "ETH") => ({
  seykota_signals: [{ asset, score: 7, action: "LONG" }],
  druckenmiller_signals: [{ asset, fundamental_signal: "STRONG_BUY", action: "ADD", reward_risk_ratio: 5.2, conviction: 8 }],
});
const run = async (req) => JSON.parse((await executeJob(req)).deliverable);

test("aligned ETH, dry run: a plan, capped, status DRY_RUN", async () => {
  const d = await run({ ...strong(), portfolio: { equity_usd: 10000, usdc_balance: 2500 }, dry_run: true });
  assert.equal(d.swap_plans.length, 1);
  assert.equal(d.swap_plans[0].status, "DRY_RUN");
  assert.equal(d.swap_plans[0].amount_usd, 100); // 10% of 10000 = 1000, absolute ceiling 100
});

test("buyer cannot loosen limits: max_swap_pct 100 and min_alignment 0", async () => {
  const d = await run({ ...strong(), portfolio: { equity_usd: 10000, usdc_balance: 2500 }, max_swap_pct: 100, min_alignment_score: 0, dry_run: true });
  assert.equal(d.config.max_swap_pct, 10);
  assert.equal(d.config.min_alignment_score, 70);
  assert.ok(d.swap_plans[0].amount_usd <= 100);
});

test("inflated equity and balance still hit the absolute ceiling", async () => {
  const d = await run({ ...strong(), portfolio: { equity_usd: 1e12, usdc_balance: 1e12 }, dry_run: true });
  assert.equal(d.swap_plans[0].amount_usd, 100);
});

test("unlisted asset is REJECTED", async () => {
  const d = await run({ ...strong("SCAMCOIN"), portfolio: { equity_usd: 10000, usdc_balance: 2500 }, dry_run: true });
  assert.equal(d.swap_plans[0].status, "REJECTED");
  assert.equal(d.rejected_count, 1);
});

test("CLOSE with an inflated position is capped", async () => {
  const d = await run({
    seykota_signals: [{ asset: "ETH", score: 0, action: "CLOSE" }],
    druckenmiller_signals: [{ asset: "ETH", fundamental_signal: "HOLD", action: "HOLD" }],
    portfolio: { existing_positions: { ETH: { size_usd: 1e9 } } },
    dry_run: true,
  });
  assert.equal(d.swap_plans[0].amount_usd, 100);
});

test("a missing signal means no trade", async () => {
  const d = await run({ seykota_signals: strong().seykota_signals, portfolio: { equity_usd: 10000, usdc_balance: 2500 }, dry_run: true });
  assert.equal(d.swap_plans.length, 0);
  assert.equal(d.alignments[0].combined_action, "NO_TRADE");
});

test("live mode without credentials fails closed", async () => {
  const d = await run({ ...strong(), portfolio: { equity_usd: 10000, usdc_balance: 2500 } });
  assert.equal(d.swap_plans[0].status, "FAILED");
  assert.equal(d.executed_count, 0);
});

test("live mode with credentials still fails closed: no fake success, no placeholder", async () => {
  process.env.CDP_API_KEY_NAME = "x";
  process.env.CDP_API_KEY_PRIVATE_KEY = "x";
  process.env.CDP_WALLET_ID = "x";
  const m = await import("../swap-orchestrator-handler.js?live");
  const out = (await m.executeJob({ ...strong(), portfolio: { equity_usd: 10000, usdc_balance: 2500 } })).deliverable;
  const d = JSON.parse(out);
  assert.equal(d.swap_plans[0].status, "FAILED");
  assert.match(d.swap_plans[0].error, /not implemented/);
  assert.doesNotMatch(out, /PLACEHOLDER/i);
  assert.equal(d.executed_count, 0);
  for (const k of ["CDP_API_KEY_NAME", "CDP_API_KEY_PRIVATE_KEY", "CDP_WALLET_ID"]) delete process.env[k];
});

test("garbage requests do not crash", async () => {
  for (const req of [{}, { seykota_signals: "x", druckenmiller_signals: 5, portfolio: 7 }, { seykota_signals: [null, 1, {}], portfolio: null }]) {
    const d = await run(req);
    assert.equal(d.swap_plans.length, 0);
  }
});

test("nodle_micro_swaps: dry run adds a 0.05 USDC -> ETH plan tagged with its source", async () => {
  const d = await run({ portfolio: { usdc_balance: 5 }, nodle_micro_swaps: { enabled: true, runs_today: 0 }, dry_run: true });
  assert.equal(d.nodle_micro_swaps.run, true);
  const p = d.swap_plans.find((x) => x.source === "nodle_micro_swaps");
  assert.equal(p.status, "DRY_RUN");
  assert.equal(p.amount_usd, 0.05);
  assert.equal(p.to_token, "ETH");
});

test("nodle_micro_swaps: skipped when the agents close ETH, and USDC committed to aligned buys is not reused", async () => {
  const closing = await run({
    seykota_signals: [{ asset: "ETH", score: 0, action: "CLOSE" }],
    druckenmiller_signals: [{ asset: "ETH", fundamental_signal: "HOLD", action: "HOLD" }],
    portfolio: { usdc_balance: 5 },
    nodle_micro_swaps: { enabled: true },
    dry_run: true,
  });
  assert.equal(closing.nodle_micro_swaps.run, false);
  const spent = await run({ ...strong(), portfolio: { equity_usd: 10000, usdc_balance: 100 }, nodle_micro_swaps: { enabled: true }, dry_run: true });
  assert.equal(spent.nodle_micro_swaps.run, false); // the $100 aligned buy uses all the USDC
});

test("deliverable lists the Base contracts and the monitoring WSS host; off by default", async () => {
  const d = await run({ ...strong(), portfolio: { equity_usd: 10000, usdc_balance: 2500 }, dry_run: true });
  assert.equal(d.config.contracts.weth9, "0x4200000000000000000000000000000000000006");
  assert.equal(d.config.monitoring_wss, "base.gateway.tenderly.co");
  assert.equal(d.nodle_micro_swaps, null);
  assert.equal(d.preflight, null);
});
