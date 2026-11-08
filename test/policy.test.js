import test from "node:test";
import assert from "node:assert/strict";
import {
  POLICY_DEFAULTS,
  loadPolicy,
  clampMaxSwapPct,
  effectiveMinAlignment,
  isAssetAllowed,
  safeUsd,
  clampSwapUsd,
  canFailOver,
  createDailyCap,
} from "../lib/orchestrator-policy.js";

const P = loadPolicy({});

test("defaults: a small allowlist, a 10% ceiling, an absolute $ ceiling, a 70 alignment floor", () => {
  assert.deepEqual([...P.allowedAssets].sort(), ["CBBTC", "ETH", "WETH"]);
  assert.equal(P.maxSwapPctCeiling, 10);
  assert.equal(P.maxSwapUsd, POLICY_DEFAULTS.maxSwapUsd);
  assert.equal(P.minAlignmentFloor, 70);
  assert.ok(P.dailyCapUsd > 0);
});

test("the environment (never a request) sets the limits; bad values fall back to the defaults", () => {
  const p = loadPolicy({
    ORCHESTRATOR_ALLOWED_ASSETS: " eth, aero ,",
    ORCHESTRATOR_MAX_SWAP_PCT: "5",
    ORCHESTRATOR_MAX_SWAP_USD: "40",
    ORCHESTRATOR_MIN_ALIGNMENT_SCORE: "85",
    ORCHESTRATOR_DAILY_CAP_USD: "120",
  });
  assert.deepEqual([...p.allowedAssets].sort(), ["AERO", "ETH"]);
  assert.deepEqual([p.maxSwapPctCeiling, p.maxSwapUsd, p.minAlignmentFloor, p.dailyCapUsd], [5, 40, 85, 120]);
  const bad = loadPolicy({ ORCHESTRATOR_MAX_SWAP_PCT: "lots", ORCHESTRATOR_MAX_SWAP_USD: "-5", ORCHESTRATOR_MIN_ALIGNMENT_SCORE: "NaN" });
  assert.equal(bad.maxSwapPctCeiling, 10);
  assert.equal(bad.maxSwapUsd, POLICY_DEFAULTS.maxSwapUsd);
  assert.equal(bad.minAlignmentFloor, 70);
  assert.equal(loadPolicy({ ORCHESTRATOR_MAX_SWAP_PCT: "500" }).maxSwapPctCeiling, 100); // a percent cannot exceed 100
});

test("max swap percent: a request can only LOWER the ceiling", () => {
  assert.equal(clampMaxSwapPct(undefined, P), 10);
  assert.equal(clampMaxSwapPct(null, P), 10);
  assert.equal(clampMaxSwapPct(100, P), 10); // the attack: ask for more
  assert.equal(clampMaxSwapPct(5, P), 5);
  assert.equal(clampMaxSwapPct(-3, P), 0);
  assert.equal(clampMaxSwapPct("abc", P), 10);
  assert.equal(clampMaxSwapPct(Infinity, P), 10);
});

test("alignment threshold: a request can only RAISE the floor", () => {
  assert.equal(effectiveMinAlignment(undefined, P), 70);
  assert.equal(effectiveMinAlignment(0, P), 70); // the attack: ask for less
  assert.equal(effectiveMinAlignment(-50, P), 70);
  assert.equal(effectiveMinAlignment(90, P), 90);
  assert.equal(effectiveMinAlignment(1000, P), 100);
  assert.equal(effectiveMinAlignment("x", P), 70);
});

test("asset allowlist: case-insensitive symbols only, non-strings never pass", () => {
  assert.equal(isAssetAllowed("ETH", P), true);
  assert.equal(isAssetAllowed("eth", P), true);
  assert.equal(isAssetAllowed(" WETH ", P), true);
  assert.equal(isAssetAllowed("SCAMCOIN", P), false);
  assert.equal(isAssetAllowed("", P), false);
  assert.equal(isAssetAllowed(undefined, P), false);
  assert.equal(isAssetAllowed({ toString: () => "ETH" }, P), false);
  assert.equal(isAssetAllowed(["ETH"], P), false);
});

test("safeUsd: only positive finite numbers count", () => {
  assert.equal(safeUsd(12.5), 12.5);
  assert.equal(safeUsd("12"), 12);
  for (const v of [NaN, -1, 0, Infinity, null, undefined, "x", {}]) assert.equal(safeUsd(v), 0, String(v));
});

test("swap amount: bounded by the absolute ceiling and by what is left of the day", () => {
  assert.equal(clampSwapUsd(1_000_000, P), P.maxSwapUsd);
  assert.equal(clampSwapUsd(30, P), 30);
  assert.equal(clampSwapUsd(30, P, 12), 12);
  assert.equal(clampSwapUsd(30, P, 0), 0);
  assert.equal(clampSwapUsd(NaN, P), 0);
  assert.equal(clampSwapUsd(-5, P), 0);
});

test("failover is allowed before a transaction is broadcast and never after", () => {
  for (const stage of ["quote", "build", "simulate"]) assert.equal(canFailOver(stage), true, stage);
  for (const stage of ["broadcast", "confirm", "pending", "", undefined, "anything-else"]) assert.equal(canFailOver(stage), false, String(stage));
});

test("daily cap: spends down, ignores junk, and resets at UTC midnight", () => {
  let t = Date.parse("2026-11-08T23:59:00Z");
  const cap = createDailyCap({ capUsd: 100, now: () => t });
  assert.equal(cap.remaining(), 100);
  cap.consume(60);
  cap.consume(-500); // negative or junk spends nothing
  cap.consume(NaN);
  assert.equal(cap.remaining(), 40);
  cap.consume(500);
  assert.equal(cap.remaining(), 0); // never negative
  t = Date.parse("2026-11-09T00:01:00Z");
  assert.equal(cap.remaining(), 100); // a new day
});
