import test from "node:test";
import assert from "node:assert/strict";
import { ROUTER_CONFIG, DEFAULT_RPCS, getRpcConfig, rpcHost, CHAIN } from "../lib/orchestrator-config.js";

test("three distinct routers, in failover order, with well-formed addresses", () => {
  assert.deepEqual(Object.keys(ROUTER_CONFIG), ["primary", "fallback_1", "fallback_2"]);
  const addrs = Object.values(ROUTER_CONFIG).map((r) => r.address.toLowerCase());
  assert.equal(new Set(addrs).size, 3);
  for (const r of Object.values(ROUTER_CONFIG)) {
    assert.match(r.address, /^0x[0-9a-fA-F]{40}$/, r.name);
    assert.ok(r.identity.length > 3, r.name);
  }
  assert.equal(CHAIN.chainId, 8453);
});

test("router identities are the contract names verified on Basescan (the old labels were wrong)", () => {
  assert.match(ROUTER_CONFIG.primary.identity, /AggregationRouterV6/); // not v5
  assert.match(ROUTER_CONFIG.fallback_1.identity, /LiFiDiamond/);
  assert.match(ROUTER_CONFIG.fallback_2.identity, /UniversalRouter/); // not a "0x-style" router
  assert.doesNotMatch(Object.values(ROUTER_CONFIG).map((r) => r.identity).join(" "), /v5|0x-style/i);
});

test("default RPCs are https, distinct, in the agreed order, and not the dead developer-access endpoint", () => {
  const urls = Object.values(DEFAULT_RPCS);
  assert.equal(new Set(urls).size, 3);
  for (const u of urls) assert.ok(u.startsWith("https://"), u);
  assert.deepEqual(urls, ["https://mainnet.base.org", "https://base.drpc.org", "https://base.api.pocket.network"]);
  assert.doesNotMatch(urls.join(" "), /developer-access-mainnet\.base\.org/); // still does not connect (2026-11-09)
});

test("environment variables override the RPC defaults, one by one", () => {
  const c = getRpcConfig({ COINBASE_RPC: "https://rpc.example/primary", FALLBACK_RPC_2: "https://rpc.example/two" });
  assert.equal(c.primary, "https://rpc.example/primary");
  assert.equal(c.fallback_1, DEFAULT_RPCS.fallback_1);
  assert.equal(c.fallback_2, "https://rpc.example/two");
});

test("rpcHost keeps the host only: an API key in the path or query never reaches a deliverable", () => {
  assert.equal(rpcHost("https://base-mainnet.g.alchemy.com/v2/SECRET_KEY_123"), "base-mainnet.g.alchemy.com");
  assert.equal(rpcHost("https://rpc.example/path?apikey=SECRET"), "rpc.example");
  assert.equal(rpcHost("not a url"), "invalid-url");
});

test("failover policy: one retry per router, bounded timeouts, abort and alert when everything fails", async () => {
  const { FAILOVER_POLICY } = await import("../lib/orchestrator-config.js");
  assert.deepEqual(FAILOVER_POLICY.router, { maxRetriesPerRouter: 1, timeoutMs: 8000, maxSlippageBps: 100, onAllFailed: "abort_and_alert" });
  assert.equal(FAILOVER_POLICY.rpc.unhealthyAfterConsecutiveFailures, 2);
  assert.equal(FAILOVER_POLICY.rpc.healthCheckIntervalSeconds, 30);
  assert.equal(FAILOVER_POLICY.rpc.onAllFailed, "abort_and_alert");
});
