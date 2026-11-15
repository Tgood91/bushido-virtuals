// 0xSplits SDK on Base, READ-ONLY. Builds a viem public client whose transport fails over across the configured RPCs
// (same order as the orchestrator), and a SplitsClient on top of it. No wallet client is created here, so nothing
// built from this module can sign or send a transaction.
//
// Requires `npm install` (@0xsplits/splits-sdk and its peer dependency viem). The orchestrator handler itself does
// not import this module, so it still runs with no dependencies installed.

import { createPublicClient, fallback, http } from "viem";
import { base } from "viem/chains";
import { SplitsClient } from "@0xsplits/splits-sdk";
import { getRpcConfig, FAILOVER_POLICY } from "./orchestrator-config.js";

export function createBasePublicClient(env = process.env) {
  const rpcs = Object.values(getRpcConfig(env));
  const { timeoutMs } = FAILOVER_POLICY.rpc;
  return createPublicClient({
    chain: base,
    transport: fallback(rpcs.map((url) => http(url, { timeout: timeoutMs, retryCount: 0 })), { retryCount: 1 }),
  });
}

/** Read-only Splits client for Base. Pass `apiConfig: { apiKey }` via opts to enable the Splits data API. */
export function createSplitsReader(env = process.env, opts = {}) {
  const publicClient = createBasePublicClient(env);
  const splitsClient = new SplitsClient({ chainId: base.id, publicClient, includeEnsNames: false, ...opts });
  return { publicClient, splitsClient };
}
