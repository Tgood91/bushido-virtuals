// Base mainnet (chain 8453) contract addresses and the real-time WebSocket endpoint used by the orchestrator.
// Plain ESM, no dependencies.
//
// Checked 2026-11-09 against mainnet.base.org: every address below has contract code deployed, WETH9 returns symbol
// "WETH", and the sequencer feed answers latestRoundData(). The two oracle factories (0xSplits oracle factories) are
// NOT listed in @0xsplits/splits-sdk's own source, so their identity is as supplied, not independently verified.
// Re-check with `npm run check:base` before trusting a changed address.

export const BASE_CONTRACTS = Object.freeze({
  weth9: "0x4200000000000000000000000000000000000006",
  sequencerFeed: "0xBCF85224fc0756B9Fa45aA7892530B47e10b6433", // Chainlink L2 sequencer uptime feed
  uniswapV3Factory: "0x33128a8fC17869897dcE68Ed026d694621f6FDfD",
  uniV3OracleFactory: "0x074827E8bD77B0A66c6008a51AF9BD1F33105caf",
  chainlinkOracleFactory: "0xD28182C2E11519ad081E7fa9da711274b7096098",
});

/** Tokens the orchestrator and the Nodle micro-swap sub-function touch. USDC is Circle's native USDC on Base. */
export const BASE_TOKENS = Object.freeze({
  USDC: { address: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913", decimals: 6 },
  WETH: { address: BASE_CONTRACTS.weth9, decimals: 18 },
});

/** WebSocket endpoint for real-time event and mempool monitoring (read-only; never used to send transactions). */
export const DEFAULT_WSS = "wss://base.gateway.tenderly.co";

export function getWssConfig(env = process.env) {
  return { monitoring: env.TENDERLY_WSS || DEFAULT_WSS };
}
