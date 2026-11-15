import test from "node:test";
import assert from "node:assert/strict";
import { executeSwap, toRawAmount } from "../lib/orchestrator-exec.js";
import { loadPolicy, createDailyCap } from "../lib/orchestrator-policy.js";
import { TOKENS, tokenFor } from "../lib/orchestrator-config.js";

const HASH = "0x" + "ab".repeat(32);
const routers = [
  { role: "primary", name: "PRIMARY_ROUTER" },
  { role: "fallback_1", name: "FALLBACK_ROUTER_1" },
  { role: "fallback_2", name: "FALLBACK_ROUTER_2" },
];
const plan = { asset: "ETH", direction: "LONG", from_token: "USDC", to_token: "ETH", amount_usd: 50, router_attempted: [], router_used: null, rpc_used: null, status: "PLANNED", tx_hash: null, error: null };

// A good adapter set that records what was called.
function good(log, name, over = {}) {
  return {
    quote: async () => (log.push(`${name}.quote`), { quoteId: "q" }),
    build: async () => (log.push(`${name}.build`), { tx: { to: "0x1" } }),
    simulate: async () => (log.push(`${name}.simulate`), { ok: true }),
    broadcast: async () => (log.push(`${name}.broadcast`), { hash: HASH }),
    confirm: async () => (log.push(`${name}.confirm`), { status: "success" }),
    ...over,
  };
}
const mk = (adapters, extra = {}) => ({
  adapters,
  policy: loadPolicy({}),
  cap: createDailyCap({ capUsd: 250 }),
  routers,
  slippageBps: 100,
  failover: { maxRetriesPerRouter: 1, timeoutMs: 200, maxSlippageBps: 100 },
  ...extra,
});

test("token table: the verified Base tokens, ETH trades as WETH", () => {
  assert.equal(TOKENS.USDC.decimals, 6);
  assert.equal(TOKENS.CBBTC.decimals, 8);
  assert.equal(tokenFor("eth"), TOKENS.WETH);
  assert.equal(tokenFor("SCAM"), null);
  assert.equal(toRawAmount(50, TOKENS.USDC, 1), 50_000_000n);
  assert.equal(toRawAmount(0, TOKENS.USDC, 1), 0n);
});

test("happy path: simulate runs before broadcast, spend recorded, EXECUTED with the hash", async () => {
  const log = [];
  const d = mk({ primary: good(log, "p") });
  const r = await executeSwap(plan, d);
  assert.equal(r.status, "EXECUTED");
  assert.equal(r.tx_hash, HASH);
  assert.equal(r.router_used, "PRIMARY_ROUTER");
  assert.deepEqual(log, ["p.quote", "p.build", "p.simulate", "p.broadcast", "p.confirm"]);
  assert.equal(d.cap.remaining(), 200);
});

test("a revert in simulation never reaches broadcast; the next router is tried", async () => {
  const log = [];
  const d = mk({
    primary: good(log, "p", { simulate: async () => (log.push("p.simulate"), { ok: false, reason: "STF" }) }),
    fallback_1: good(log, "f1"),
  });
  const r = await executeSwap(plan, d);
  assert.equal(r.status, "EXECUTED");
  assert.equal(r.router_used, "FALLBACK_ROUTER_1");
  assert.ok(!log.includes("p.broadcast"));
  assert.equal(log.filter((x) => x === "p.simulate").length, 2); // one retry
});

test("quote failure and timeout fail over", async () => {
  const log = [];
  const d = mk({
    primary: good(log, "p", { quote: async () => { throw new Error("boom"); } }),
    fallback_1: good(log, "f1", { quote: () => new Promise(() => {}) }), // never answers
    fallback_2: good(log, "f2"),
  });
  const r = await executeSwap(plan, d);
  assert.equal(r.status, "EXECUTED");
  assert.equal(r.router_used, "FALLBACK_ROUTER_2");
  assert.deepEqual(r.router_attempted, ["PRIMARY_ROUTER", "FALLBACK_ROUTER_1", "FALLBACK_ROUTER_2"]);
});

test("all routers fail before broadcast: abort, nothing broadcast, nothing spent", async () => {
  const bad = (n) => good([], n, { quote: async () => { throw new Error("down"); } });
  const d = mk({ primary: bad("p"), fallback_1: bad("f1"), fallback_2: bad("f2") });
  const r = await executeSwap(plan, d);
  assert.equal(r.status, "FAILED");
  assert.match(r.error, /Abort and alert/);
  assert.equal(d.cap.remaining(), 250);
});

test("a broadcast error is NOT retried or failed over, and the spend stays recorded", async () => {
  const log = [];
  const d = mk({
    primary: good(log, "p", { broadcast: async () => { log.push("p.broadcast"); throw new Error("socket hang up"); } }),
    fallback_1: good(log, "f1"),
  });
  const r = await executeSwap(plan, d);
  assert.equal(r.status, "FAILED");
  assert.match(r.error, /Outcome unknown/);
  assert.equal(log.filter((x) => x.endsWith(".broadcast")).length, 1);
  assert.ok(!log.some((x) => x.startsWith("f1.")));
  assert.equal(d.cap.remaining(), 200);
});

test("an unconfirmed transaction is PENDING with the original hash, never re-sent", async () => {
  const log = [];
  const d = mk({ primary: good(log, "p", { confirm: async () => ({ status: "pending" }) }), fallback_1: good(log, "f1") });
  const r = await executeSwap(plan, d);
  assert.equal(r.status, "PENDING");
  assert.equal(r.tx_hash, HASH);
  assert.ok(!log.some((x) => x.startsWith("f1.")));
});

test("a reverted transaction is FAILED but keeps its hash", async () => {
  const d = mk({ primary: good([], "p", { confirm: async () => ({ status: "reverted" }) }) });
  const r = await executeSwap(plan, d);
  assert.equal(r.status, "FAILED");
  assert.equal(r.tx_hash, HASH);
});

test("a malformed hash from the signer is treated as unknown, not success", async () => {
  const d = mk({ primary: good([], "p", { broadcast: async () => ({ hash: "nope" }) }) });
  const r = await executeSwap(plan, d);
  assert.equal(r.status, "FAILED");
  assert.match(r.error, /no valid transaction hash/);
});

test("the cap is enforced again at execution time", async () => {
  const d = mk({ primary: good([], "p") });
  d.cap.consume(250);
  const r = await executeSwap(plan, d);
  assert.equal(r.status, "FAILED");
  assert.match(r.error, /Nothing left/);
  const big = mk({ primary: good([], "p") });
  const r2 = await executeSwap({ ...plan, amount_usd: 1e6 }, big);
  assert.equal(r2.amount_usd, 100); // the absolute per-swap ceiling
});

test("unknown tokens, or selling a non-USDC token with no price, do not trade", async () => {
  const d = mk({ primary: good([], "p") });
  assert.match((await executeSwap({ ...plan, to_token: "SCAM" }, d)).error, /verified Base token table/);
  const sell = await executeSwap({ ...plan, from_token: "ETH", to_token: "USDC" }, d);
  assert.equal(sell.status, "FAILED");
  assert.match(sell.error, /no price/);
  const priced = mk({ primary: good([], "p") }, { usdPerToken: { ETH: 2500 } });
  assert.equal((await executeSwap({ ...plan, from_token: "ETH", to_token: "USDC" }, priced)).status, "EXECUTED");
});

test("no adapters configured: fails closed", async () => {
  const r = await executeSwap(plan, mk({}));
  assert.equal(r.status, "FAILED");
});
