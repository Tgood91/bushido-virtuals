import test from "node:test";
import assert from "node:assert/strict";

// Needs `npm ci` (@0xsplits/splits-sdk + viem). Building the clients makes no network call.
test("Splits reader is built for Base, read-only, over the failover RPCs", async () => {
  const { createSplitsReader } = await import("../lib/splits.js");
  const { publicClient, splitsClient } = createSplitsReader({});
  assert.equal(publicClient.chain.id, 8453);
  assert.equal(publicClient.transport.type, "fallback");
  assert.equal(publicClient.transport.transports.length, 3);
  assert.ok(splitsClient);
  assert.equal(typeof publicClient.sendTransaction, "undefined"); // a public client cannot send transactions
});
