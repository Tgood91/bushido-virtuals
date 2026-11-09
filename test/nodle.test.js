import test from "node:test";
import assert from "node:assert/strict";
import { planNodleMicroSwap } from "../lib/nodle-micro-swaps.js";
import { loadPolicy } from "../lib/orchestrator-policy.js";

const policy = loadPolicy({});
const run = (o) => planNodleMicroSwap({ usdcBalance: 10, policy, ...o });

test("plans 0.05 USDC -> ETH when nothing blocks it", () => {
  const p = run({});
  assert.equal(p.run, true);
  assert.equal(p.amount_usd, 0.05);
  assert.equal(p.from_token, "USDC");
  assert.equal(p.to_token, "ETH");
});

test("skips when the agents are bearish on ETH", () => {
  assert.equal(run({ ethAction: "EXECUTE_SHORT" }).run, false);
  assert.equal(run({ ethAction: "EXECUTE_CLOSE" }).run, false);
  assert.equal(run({ ethAction: "NO_TRADE" }).run, true);
});

test("stop condition, 3-a-day limit, daily cap, allowlist", () => {
  assert.equal(run({ usdcBalance: 0.04 }).run, false);
  assert.equal(run({ runsToday: 3 }).run, false);
  assert.equal(run({ remainingDailyUsd: 0.01 }).run, false);
  assert.equal(planNodleMicroSwap({ usdcBalance: 10, policy: loadPolicy({ ORCHESTRATOR_ALLOWED_ASSETS: "CBBTC" }) }).run, false);
  assert.equal(run({ usdcBalance: "junk" }).run, false);
});
