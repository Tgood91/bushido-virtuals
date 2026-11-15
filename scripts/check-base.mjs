// Live check of the Base endpoints and contracts the orchestrator depends on. Read-only; run: npm run check:base
import { getRpcConfig, rpcHost } from "../lib/orchestrator-config.js";
import { BASE_CONTRACTS, getWssConfig } from "../lib/base-contracts.js";
import { readSequencerStatus } from "../lib/chain-guards.js";

const rpcs = Object.entries(getRpcConfig());
const post = async (url, method, params) => {
  const r = await fetch(url, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }), signal: AbortSignal.timeout(8000) });
  const b = await r.json();
  if (b.error) throw new Error(b.error.message);
  return b.result;
};
let failures = 0;
for (const [name, url] of rpcs) {
  try {
    const id = await post(url, "eth_chainId", []);
    console.log(`${id === "0x2105" ? "ok  " : "BAD "} rpc ${name} ${rpcHost(url)} chainId=${id}`);
    if (id !== "0x2105") failures++;
  } catch (e) { failures++; console.log(`FAIL rpc ${name} ${rpcHost(url)}: ${e.cause?.code || e.message}`); }
}
const wss = getWssConfig().monitoring;
await new Promise((res) => {
  const ws = new WebSocket(wss);
  const t = setTimeout(() => { failures++; console.log(`FAIL wss ${rpcHost(wss)}: timeout`); ws.close(); res(); }, 8000);
  ws.onopen = () => ws.send(JSON.stringify({ jsonrpc: "2.0", id: 1, method: "eth_chainId", params: [] }));
  ws.onmessage = (e) => { clearTimeout(t); const ok = JSON.parse(e.data).result === "0x2105"; if (!ok) failures++; console.log(`${ok ? "ok  " : "BAD "} wss ${rpcHost(wss)}`); ws.close(); res(); };
  ws.onerror = () => { clearTimeout(t); failures++; console.log(`FAIL wss ${rpcHost(wss)}`); res(); };
});
const url = rpcs[0][1];
for (const [name, addr] of Object.entries(BASE_CONTRACTS)) {
  try {
    const code = await post(url, "eth_getCode", [addr, "latest"]);
    const n = (code.length - 2) / 2;
    if (!n) failures++;
    console.log(`${n ? "ok  " : "FAIL"} ${name} ${addr} code=${n} bytes`);
  } catch (e) { failures++; console.log(`FAIL ${name}: ${e.message}`); }
}
const seq = await readSequencerStatus(rpcs.map(([, u]) => u));
if (!seq.ok) failures++;
console.log(`${seq.ok ? "ok  " : "FAIL"} sequencer: ${seq.reason}`);
process.exitCode = failures ? 1 : 0;
