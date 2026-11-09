/**
 * ACP JOB SCHEDULER CONFIG
 * 
 * Add this to your acp-jobs.config.ts or agent orchestration file
 * Schedules the virtuals-dip-buy job to run every hour
 */

export const VIRTUALS_DIP_BUY_JOB = {
  // Unique job identifier
  id: "virtuals-dip-buy",

  // Cron schedule: Every hour at :00
  // "0 * * * *" = 00:00, 01:00, 02:00, ... 23:00 UTC
  cron: "0 * * * *",

  // Path to handler file (relative to job runner)
  handler: "./handlers/virtuals-dip-buy.js",

  // Job metadata
  name: "VIRTUALS Dip Buy",
  description: "Auto-swap $0.025 USDC → VIRTUALS when price drops -4% in 12 hours",
  category: "DeFi Arbitrage",
  risk: "LOW",

  // Execution settings
  timeout: 60000,              // Max 60 seconds per execution
  retries: 1,                  // Retry once on failure
  retryDelay: 5000,            // Wait 5s before retry

  // Alerts
  alerts: {
    onSuccess: {
      type: "discord",
      channel: "trading-signals",
      mention: ["@trader"],
    },
    onFailure: {
      type: "discord",
      channel: "trading-alerts",
      mention: ["@dev"],
      severity: "HIGH",
    },
  },

  // Environment variables required
  env: {
    AGENT_WALLET_ADDRESS: "process.env.AGENT_WALLET_ADDRESS",
    AGENT_PRIVATE_KEY: "process.env.AGENT_PRIVATE_KEY",
    ALCHEMY_API_KEY: "process.env.ALCHEMY_API_KEY",
  },

  // Enable/disable
  enabled: true,
};
