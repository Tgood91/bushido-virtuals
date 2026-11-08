// EXAMPLE ONLY (not run by anything in this repo). It shows how to register the dip-buy job with a scheduler.
// It used to sit at the bottom of virtuals-dip-buy.config.ts, where it imported the config's own name from the same
// file: a duplicate-declaration error that stopped the config from loading. The import paths below assume the ACP
// runtime's layout (jobs/ and handlers/ folders); adjust them to where you copy the config and the handler.

// ──────────────────────────────────────────────────────────────────────────────
// INTEGRATION EXAMPLE: Add to your main scheduler
// ──────────────────────────────────────────────────────────────────────────────

import cron from "node-cron";
import { VIRTUALS_DIP_BUY_JOB } from "./jobs/virtuals-dip-buy.config.js";
import { executeJob } from "./handlers/virtuals-dip-buy.js";

// Register the job
export function registerVirtualsDipBuy() {
  if (!VIRTUALS_DIP_BUY_JOB.enabled) {
    console.log(`⊘ Job ${VIRTUALS_DIP_BUY_JOB.id} is disabled`);
    return;
  }

  console.log(`📌 Registering job: ${VIRTUALS_DIP_BUY_JOB.name}`);

  cron.schedule(VIRTUALS_DIP_BUY_JOB.cron, async () => {
    try {
      const result = await executeJob();
      console.log(`✓ ${VIRTUALS_DIP_BUY_JOB.name} completed:`, result);
      
      // Post alert if swap executed
      if (result.status === "success") {
        await postAlert(VIRTUALS_DIP_BUY_JOB.alerts.onSuccess, result);
      }
    } catch (error) {
      console.error(`❌ ${VIRTUALS_DIP_BUY_JOB.id} failed:`, error);
      await postAlert(VIRTUALS_DIP_BUY_JOB.alerts.onFailure, error);
    }
  });

  console.log(`✓ Job scheduled: ${VIRTUALS_DIP_BUY_JOB.cron}`);
}

// Add to main agent initialization
export function initializeAllJobs() {
  registerVirtualsDipBuy();
  // ... register other jobs
}

// ──────────────────────────────────────────────────────────────────────────────
// STANDALONE USAGE (for testing)
// ──────────────────────────────────────────────────────────────────────────────

// Run once immediately (for testing):
// node -e "import('./handlers/virtuals-dip-buy.js').then(m => m.executeJob())"

// Or with npx:
// npx ts-node handlers/virtuals-dip-buy.js
