// Static configuration for the swap orchestrator (Base chain): routers, RPC endpoints, defaults.
// Plain ESM with no dependencies so the handler and the tests can both import it.

export const CHAIN = { name: "Base", chainId: 8453 };

/**
 * Routers, tried in this order. `identity` is the contract name from the VERIFIED source on Basescan
 * (checked 2026-11-08), not a guess:
 *   0x1111...2A65  AggregationRouterV6  (1inch v6; the v5 router is a different address)
 *   0x1231...4EaE  LiFiDiamond          (LI.FI)
 *   0x6fF5...9b43  UniversalRouter      (Uniswap; not a "0x-style" router)
 * Re-verify against each project's official deployment list before trusting a new address.
 */
export const ROUTER_CONFIG = {
  primary: {
    name: "PRIMARY_ROUTER",
    address: "0x111111125421cA6dc452d289314280a0f8842A65",
    identity: "1inch AggregationRouterV6",
  },
  fallback_1: {
    name: "FALLBACK_ROUTER_1",
    address: "0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE",
    identity: "LI.FI Diamond (LiFiDiamond)",
  },
  fallback_2: {
    name: "FALLBACK_ROUTER_2",
    address: "0x6fF5693b99212Da76ad316178A184AB56D299b43",
    identity: "Uniswap UniversalRouter",
  },
};

/**
 * Default Base RPC endpoints (HTTP), in failover order. Checked 2026-11-09 with eth_chainId (all return 0x2105):
 *   mainnet.base.org, 1rpc.io/base (answering again; it failed on 2026-11-08), base.api.pocket.network.
 * developer-access-mainnet.base.org still does not connect, so it is not a default; base.drpc.org also works and is a
 * good value for an override. Set COINBASE_RPC / FALLBACK_RPC_1 / FALLBACK_RPC_2 to override (keep any key out of the
 * repo). The real-time WebSocket endpoint (TENDERLY_WSS) is in base-contracts.js.
 */
export const DEFAULT_RPCS = {
  primary: "https://mainnet.base.org",
  fallback_1: "https://1rpc.io/base",
  fallback_2: "https://base.api.pocket.network",
};

export function getRpcConfig(env = process.env) {
  return {
    primary: env.COINBASE_RPC || DEFAULT_RPCS.primary,
    fallback_1: env.FALLBACK_RPC_1 || DEFAULT_RPCS.fallback_1,
    fallback_2: env.FALLBACK_RPC_2 || DEFAULT_RPCS.fallback_2,
  };
}

/**
 * Failover policy numbers (from the integration notes; the values are settings, not measurements).
 * Nothing in the handler retries yet because live execution is not wired: these are the limits to use when it is.
 * `maxSlippageBps` is a ceiling a request may not raise (see clampSlippageBps in orchestrator-policy.js).
 */
export const FAILOVER_POLICY = {
  router: { maxRetriesPerRouter: 1, timeoutMs: 8000, maxSlippageBps: 100, onAllFailed: "abort_and_alert" },
  rpc: { healthCheckIntervalSeconds: 30, timeoutMs: 5000, unhealthyAfterConsecutiveFailures: 2, onAllFailed: "abort_and_alert" },
};

/** Host only, for logs and deliverables: an RPC URL can carry an API key in its path or query. */
export function rpcHost(url) {
  try {
    return new URL(url).host;
  } catch {
    return "invalid-url";
  }
}
