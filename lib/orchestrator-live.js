// Concrete (network and signing) adapters for live execution. Deliberately returns null until they exist.
//
// The state machine in orchestrator-exec.js is complete and tested; what is missing is the part that needs real
// credentials and cannot be verified offline:
//   - quote/build per router (1inch API key, LI.FI, Uniswap UniversalRouter calldata)
//   - simulate via eth_call on a working RPC (getRpcConfig)
//   - broadcast: sign and send from the CDP wallet (CDP_API_KEY_NAME / CDP_API_KEY_PRIVATE_KEY / CDP_WALLET_ID)
//   - confirm: eth_getTransactionReceipt
// Implement createLiveAdapters(env) to return { adapters: { primary, fallback_1, fallback_2 }, usdPerToken } and the
// handler will use it. Until then a live job fails closed.

export function createLiveAdapters(_env = process.env) {
  return null;
}
