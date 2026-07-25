# VIRTUALS Dip-Buy Job — Architecture Overview

## What This Is

A **standalone, automated dip-buying job** that:
- Monitors BASE_VIRTUALS price every hour
- Executes a $0.025 USDC → VIRTUALS swap when price drops -4% in 12 hours
- Posts signals to degen.virtuals.io
- Operates independently from your Seykota trend-following agent

**Why separate?**
- Seykota follows trends (momentum)
- This job catches dips (mean reversion)
- Both strategies can coexist without interfering

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      ACP AGENT SCHEDULER                        │
│                                                                 │
│  ┌──────────────────┐     ┌──────────────────┐                │
│  │  SEYKOTA JOBS    │     │ VIRTUALS DIP-BUY │                │
│  │ (Trend Following)│     │    (This Job)     │                │
│  │                  │     │                   │                │
│  │ • vol-pulse      │     │ • Price Monitor   │                │
│  │ • funding-tick   │     │   (every 1h)      │                │
│  │ • gamma-exposure │     │                   │                │
│  │ • EMA Scorer     │     │ • Trigger Check   │                │
│  │                  │     │   (-4% in 12h)    │                │
│  │ • ATR Risk Size  │     │                   │                │
│  │ • Trailing Stops │     │ • Auto Swap       │                │
│  └────────┬─────────┘     │   (if triggered)  │                │
│           │               │                   │                │
│           └───────────────┴──────────┬────────┘                │
│                                      │                         │
│                          ┌───────────▼─────────┐              │
│                          │  EXECUTION LAYER    │              │
│                          │                     │              │
│                          │ • DegenClaw CLI     │              │
│                          │ • Uniswap V3 SDK    │              │
│                          │ • Alchemy Provider  │              │
│                          │ • Discord Alerts    │              │
│                          └─────────────────────┘              │
└─────────────────────────────────────────────────────────────────┘
                            │
                ┌───────────┴───────────┐
                │                       │
        ┌───────▼────────┐      ┌─────▼──────────┐
        │  Hyperliquid   │      │  Base Network  │
        │   (Perps)      │      │  (Spot Swaps)  │
        │                │      │                │
        │ • Long/Short   │      │ • USDC → VIRT  │
        │ • Funding Farm │      │ • Price Oracle │
        │                │      │ • TVL/Volume   │
        └────────────────┘      └────────────────┘
```

---

## File Structure

```
your-acp-agent/
│
├── handlers/
│   ├── vol-pulse.js
│   ├── funding-tick.js
│   ├── gamma-exposure.js
│   ├── ... (Seykota jobs)
│   └── virtuals-dip-buy.js          ← This job (NEW)
│
├── jobs/
│   ├── seykota-jobs.config.ts       (existing)
│   └── virtuals-dip-buy.config.ts   ← Config (NEW)
│
├── services/
│   ├── hyperliquid.service.js       (existing)
│   ├── deribit.service.js           (existing)
│   └── ... (other services)
│
├── agent.ts                          (main entry)
├── .env                              (secrets)
└── package.json                      (dependencies)
```

---

## Execution Flow

### Hourly (Every :00 UTC)

```
[00:00] CRON TRIGGERS
   ↓
[1] FETCH PRICE DATA
   • Current VIRTUALS price from CoinGecko
   • 12h ago price from Alchemy historical
   ↓
[2] CALCULATE CHANGE
   • (current - 12h_ago) / 12h_ago
   • Example: ($2.10 - $2.19) / $2.19 = -4.1%
   ↓
[3] CHECK TRIGGER
   • Is change ≤ -4%?
   • No  → Log "no trigger" → Exit ✓
   • Yes → Continue
   ↓
[4] VALIDATE WALLET
   • Check USDC balance ≥ $0.05
   • Insufficient? → Log warning → Exit
   ↓
[5] EXECUTE SWAP
   • Initiate $0.025 USDC → VIRTUALS
   • Via Uniswap V3 on Base network
   • Max slippage 1%
   ↓
[6] POST SIGNAL
   • Send result to degen.virtuals.io
   • Include TX hash, amount, price
   ↓
[7] RETURN RESULT
   • Log success/failure
   • Alert if needed
```

**Typical run time:** 5-15 seconds per execution

---

## Configuration Parameters

| Parameter | Value | Notes |
|-----------|-------|-------|
| **Frequency** | Every 1 hour | `"0 * * * *"` in cron syntax |
| **Trigger** | -4% in 12h | `PRICE_DROP_THRESHOLD: -0.04` |
| **Swap Amount** | $0.025 USDC | `SWAP_AMOUNT_USD: 0.025` |
| **Slippage** | 1% max | `MAX_SLIPPAGE_PCT: 0.01` |
| **Min Balance** | $0.05 | `MIN_BALANCE_USDC: 0.05` |
| **Execution** | Uniswap V3 | on Base network |

**All configurable** in `handlers/virtuals-dip-buy.js` (lines 9-26)

---

## Integration with Seykota

### Recommended: Keep Separate Capital

```
Account: $1,000

├── Seykota Trend Following
│   ├── $800 allocated
│   ├── Long/Short positions
│   └── Trailing stops, pyramiding
│
└── Virtuals Dip-Buy
    ├── $200 allocated
    ├── Micro buys on dips
    └── Independent from trend logic
```

**Why?**
- Seykota = momentum (follows trends)
- Dip-Buy = mean reversion (catch bottoms)
- Different risk profiles, different timeframes
- Separate P&L tracking

### Optional: Combine Signals

**Scenario:** Increase dip-buy size if Seykota is bullish
```javascript
// Check Seykota's latest score for VIRTUALS
const seykotaScore = await getLatestScore("VIRTUALS");

if (seykotaScore >= 5 && priceDropTriggered) {
  // Both bullish signals = do dip-buy at 2x size
  SWAP_AMOUNT_USD = 0.05;
} else if (seykotaScore <= -5 && priceDropTriggered) {
  // Conflict: Seykota short, but price dipped
  // Skip dip-buy for safety
  return { status: "skipped", reason: "seykota_bearish" };
}
```

---

## Monitoring & Alerting

### Logs to Check

```bash
# Watch live execution
tail -f logs/agent.log | grep virtuals-dip-buy

# Or search for specific events
grep "TRIGGER HIT" logs/agent.log
grep "SWAP EXECUTED" logs/agent.log
grep "FAILED" logs/agent.log
```

### Discord Alerts (if configured)

**On Swap Success:**
```
✓ VIRTUALS DIP-BUY EXECUTED
Price: -4.05% over 12h
Swapped: $0.025 USDC → 0.0116 VIRTUALS
TX: 0x1234...abcd
```

**On Errors:**
```
❌ VIRTUALS DIP-BUY FAILED
Reason: Insufficient USDC balance
Current balance: $0.02 (need $0.05)
```

---

## Safety Features

### 1. Dry-Run Mode
Test without executing real trades:
```javascript
DRY_RUN: true,  // Toggle to disable real swaps
```

### 2. Min Balance Check
Won't execute if wallet has < $0.05 USDC

### 3. Slippage Protection
Max 1% price slippage tolerance

### 4. Rate Limiting
Only one swap per hour (even if triggered multiple times)

### 5. Error Retry
Automatic 1 retry on failure with 5s delay

---

## Costs & Economics

### Per Execution (Hourly)

| Item | Cost | Notes |
|------|------|-------|
| Gas (Base network) | ~$0.001 | Very cheap |
| Uniswap 0.3% fee | ~$0.000075 | On $0.025 |
| Total per trade | ~$0.002 | Negligible |

**Annual:** $0.002 × 24 × 365 = **~$17.50**

### P&L Breakeven

- Need to catch **2% average dip** to breakeven ($0.025 at -4% gets $0.000058 at entry)
- Most VIRTUALS -4% moves recover quickly (mean reversion)
- Conservative: Expect 0.5–2% gains per trigger

---

## Deployment Checklist

- [ ] Copy `virtuals-dip-buy.js` to `handlers/`
- [ ] Copy `virtuals-dip-buy.config.ts` to `jobs/`
- [ ] Add env vars to `.env` (see SETUP_GUIDE.md)
- [ ] Run `node test-setup.js` to validate
- [ ] Test in dry-run: `node handlers/virtuals-dip-buy.js`
- [ ] Enable live: Set `DRY_RUN: false`
- [ ] Register with scheduler: `registerVirtualsDipBuy()`
- [ ] Monitor logs for 24h
- [ ] Adjust parameters if needed

---

## Example: Real Trade Scenario

**Tuesday, Jan 15 @ 14:00 UTC**

```
[14:00:00] ✓ Price check
  Current: $2.15 VIRTUALS
  12h ago: $2.24 VIRTUALS
  Change: -4.02% ← TRIGGER!

[14:00:03] ✓ Balance check
  USDC available: $0.18
  Required: $0.025 ✓

[14:00:08] ✓ Swap initiated
  Input:  $0.025 USDC
  Output: 0.0116 VIRTUALS (at 1% slippage)
  Gas:    $0.001

[14:00:12] ✓ TX confirmed
  Hash: 0xabcd1234...
  Block: 15,234,567

[14:00:15] ✓ Signal posted
  degen.virtuals.io/post/xyz123

[14:00:16] COMPLETE
  Status: success
  P&L: Pending (depends on future price)
```

**P&L in 24h:** +2% → $0.025 × 1.02 = $0.0255 gain = +$0.0005 (+2%)

---

## Troubleshooting

**"No trigger (every hour)"**
- Normal! Only triggers when price drops -4% in 12h (rare)
- Check VIRTUALS price trend: https://www.coingecko.com/en/coins/virtuals

**"Insufficient balance"**
- Job needs $0.05 USDC minimum in wallet
- Current balance too low
- Fix: Fund wallet with more USDC

**"API timeout / unreachable"**
- CoinGecko/Alchemy API may be down
- Job retries automatically
- Check: https://status.alchemy.com

**"Swap failed with slippage"**
- Market volatility exceeded 1% max slippage
- Adjust: `MAX_SLIPPAGE_PCT: 0.02` (for 2%)

---

## Next Steps

1. **Deploy:** Follow SETUP_GUIDE.md
2. **Monitor:** Watch logs for first 24h
3. **Optimize:** Adjust swap amount, trigger threshold
4. **Combine:** Consider pairing with Seykota signals
5. **Scale:** Once comfortable, increase to $0.05+ per dip

---

**Built for:** ACP Agents running on Seykota Spirit  
**Network:** Base (Ethereum L2)  
**Token:** VIRTUALS (BASE_VIRTUALS)  
**Strategy:** Mechanical dip-buying + mean reversion

