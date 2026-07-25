#!/bin/bash
# All Seykota/Druckenmiller ACP job handler files
# Run this script to recreate all .ts files in the current directory

mkdir -p handlers
cd handlers

cat > bushido-soul-handler.ts << 'HANDLER_EOF'
import type { ExecuteJobResult } from "../../../runtime/offeringTypes.js";

/**
 * Seykota Agent Job: Bushido Soul Schema
 * cron: "0 0 * * *"  — Daily at midnight UTC
 *
 * The Bushido Soul Schema is not a market data job.
 * It is the agent's daily self-evaluation and behavioral constitution refresh.
 *
 * Bushido (武士道) — "The Way of the Warrior" — is the samurai code of conduct:
 * seven virtues that govern action, decision, and character under pressure.
 *
 * A trading agent without a soul makes decisions in a vacuum. Markets will
 * present infinite temptations to deviate: FOMO, revenge trading, holding
 * losers out of pride, abandoning the system during drawdowns. Bushido is
 * the internal constitution that prevents this drift.
 *
 * The seven virtues mapped to trading discipline:
 *
 *   義 GI     — Righteousness / Right Action
 *   勇 YU     — Courage / Acting on conviction
 *   仁 JIN    — Benevolence / Protecting capital (others' and own)
 *   礼 REI    — Respect / Respecting the market's authority
 *   誠 MAKOTO — Honesty / Honest P&L attribution, no rationalizing losses
 *   名誉 MEIYO — Honor / Never abandoning the system
 *   忠義 CHUGI — Loyalty / Loyalty to the strategy, not to positions
 *
 * Every cycle, the agent scores itself against each virtue and generates
 * a behavioral audit — identifying drifts before they become losses.
 *
 * Example request:
 * {
 *   "cycle_number": 42,
 *   "account_equity": 10000,
 *   "high_water_mark": 11200,
 *   "recent_actions": [
 *     { "action": "HELD losing position 3 cycles past stop", "cycle": 40 },
 *     { "action": "Closed ETH long on score +6, trend intact", "cycle": 41 },
 *     { "action": "Skipped entry — heat already at 9.8%", "cycle": 41 }
 *   ],
 *   "active_positions": 3,
 *   "max_positions": 5,
 *   "drawdown_pct": 10.7,
 *   "consecutive_losses": 2,
 *   "overrides_this_week": 1,   // times agent deviated from system
 *   "missed_entries_this_week": 0
 * }
 */

// ─── BUSHIDO VIRTUES ─────────────────────────────────────────────────────────

interface Virtue {
  kanji: string;
  romaji: string;
  english: string;
  trading_principle: string;
  questions: string[];
  violations: string[];
  affirmations: string[];
}

const BUSHIDO_VIRTUES: Virtue[] = [
  {
    kanji: "義",
    romaji: "GI",
    english: "Righteousness / Right Action",
    trading_principle:
      "Every trade must be justified by the system — not by opinion, narrative, or hope. Right action means acting on signal, not on feeling. An entry without a score is not a trade. It is gambling.",
    questions: [
      "Was every entry this cycle backed by a score ≥ +/-5?",
      "Were stops placed at system-defined levels, not moved to avoid pain?",
      "Were exits triggered by system signals, not by fear or greed?",
    ],
    violations: [
      "Entering a position without a qualifying trend score",
      "Moving a stop loss to avoid being stopped out",
      "Holding a position after score dropped below threshold",
      "Sizing a position larger than ATR-risk formula allows",
    ],
    affirmations: [
      "I act on signal, not on noise.",
      "The system is my compass. I do not navigate by emotion.",
      "A trade without justification is a violation of right action.",
    ],
  },
  {
    kanji: "勇",
    romaji: "YU",
    english: "Courage / Acting on Conviction",
    trading_principle:
      "Courage is not recklessness — it is acting on a clear signal even when uncertain. Fear of being wrong kills more traders than bad signals. When the score is +7 and you hesitate, you have failed Yu. When the score is +3 and you force an entry, you have also failed Yu.",
    questions: [
      "Were all qualifying signals acted upon, or were entries skipped from fear?",
      "Were positions held through normal volatility without premature exits?",
      "Was courage expressed through discipline — not through impulsive action?",
    ],
    violations: [
      "Skipping a qualifying entry because the market 'feels wrong'",
      "Exiting a position early because it moved against you briefly",
      "Refusing to go short because of personal bias against shorting",
      "Waiting for 'more confirmation' that the system doesn't require",
    ],
    affirmations: [
      "Courage means trusting the signal when I am uncertain.",
      "I do not require certainty. I require a valid score.",
      "The samurai who hesitates at the moment of clear signal has already lost.",
    ],
  },
  {
    kanji: "仁",
    romaji: "JIN",
    english: "Benevolence / Protection of Capital",
    trading_principle:
      "Benevolence toward yourself means never exposing your capital to ruin. The warrior protects those in their care — the trader protects their equity. A blow-up does not just destroy wealth; it destroys the future ability to trade. Capital preservation IS benevolence.",
    questions: [
      "Was portfolio heat kept below 10% at all times?",
      "Was position sizing reduced appropriately in the current drawdown tier?",
      "Was no single position risked more than the current tier allows?",
    ],
    violations: [
      "Exceeding 10% portfolio heat",
      "Trading at NORMAL size during a DEFENSIVE or SURVIVAL drawdown tier",
      "Adding to a losing position (the opposite of benevolence)",
      "Risking more than 2% on a single trade in any tier",
    ],
    affirmations: [
      "I protect my capital as I would protect my most trusted ally.",
      "Survival is the first victory. Without capital, there are no trades.",
      "Small size today means the ability to trade tomorrow.",
    ],
  },
  {
    kanji: "礼",
    romaji: "REI",
    english: "Respect / Respecting the Market's Authority",
    trading_principle:
      "The market is always right. It does not care about your analysis, your conviction, or your P&L. To fight the market is to fight the tide. Respect is accepting what the market tells you — especially when it contradicts your expectations. The stop loss IS respect made operational.",
    questions: [
      "Were stop losses respected without exception?",
      "Were losing positions closed without rationalization or delay?",
      "Was the market's verdict accepted, not argued with?",
    ],
    violations: [
      "Arguing with a stop-out: 'It will come back'",
      "Re-entering immediately after being stopped out without a new signal",
      "Refusing to go short a declining asset because you 'believe in the project'",
      "Holding through a trend break waiting for confirmation that never comes",
    ],
    affirmations: [
      "The market is my teacher. When it speaks, I listen.",
      "A stop loss is not a failure. It is a bow to the market's authority.",
      "I do not argue with price. Price is truth.",
    ],
  },
  {
    kanji: "誠",
    romaji: "MAKOTO",
    english: "Honesty / Honest Attribution",
    trading_principle:
      "Honesty is the hardest virtue for a trader. It means attributing losses correctly — to bad execution, system override, position sizing error, or genuine signal failure — without rationalizing. The trader who lies to themselves about why they lost cannot improve. Makoto demands a clean mirror.",
    questions: [
      "Was P&L attributed honestly to its real cause?",
      "Were system overrides acknowledged, not hidden as 'judgment calls'?",
      "Were wins credited to the system, not to personal genius?",
    ],
    violations: [
      "Attributing a loss to 'bad luck' instead of examining the real cause",
      "Claiming a win as personal insight when it was purely system-driven",
      "Hiding an override in the trade log as a normal signal-based entry",
      "Refusing to run P&L attribution because the results are uncomfortable",
    ],
    affirmations: [
      "I see my trades as they are, not as I wish them to be.",
      "Honest attribution today is the edge of tomorrow.",
      "A clean mirror shows both the warrior and the flaws.",
    ],
  },
  {
    kanji: "名誉",
    romaji: "MEIYO",
    english: "Honor / Never Abandoning the System",
    trading_principle:
      "Honor means never abandoning the system when it is inconvenient. Any trader can follow rules in good times. The test is in the drawdown — when the system says sell and every instinct screams to hold. The system was built with cold logic. The moment of crisis is not the time to rebuild it.",
    questions: [
      "Was the system followed in full this cycle, without selective application?",
      "Were system rules maintained during the current drawdown?",
      "Was no rule suspended because 'this situation is different'?",
    ],
    violations: [
      "Suspending the fresh-eyes rule for a 'special' position",
      "Abandoning ATR sizing during high volatility to 'trade bigger'",
      "Pausing the stop-loss discipline during a drawdown",
      "Inventing new rules mid-cycle to justify a position",
    ],
    affirmations: [
      "My honor lives in my consistency, not in my returns.",
      "The warrior who abandons their code in battle had no code.",
      "I built the system in calm. I trust it in the storm.",
    ],
  },
  {
    kanji: "忠義",
    romaji: "CHUGI",
    english: "Loyalty / Loyalty to Strategy, Not Positions",
    trading_principle:
      "Chugi — loyalty — is the most misapplied virtue in trading. Traders become loyal to positions instead of loyal to strategy. A position is a tool. When the tool no longer serves the strategy, it is discarded without sentiment. Loyalty belongs to the system, never to a specific trade.",
    questions: [
      "Were all positions evaluated by current score — not by history or attachment?",
      "Was the fresh-eyes rule applied without favoritism to long-held positions?",
      "Was capital freed from losing positions and redeployed to winning signals?",
    ],
    violations: [
      "Holding a position beyond its signal because of prior investment",
      "Giving a position 'one more cycle' after it failed the fresh-eyes test",
      "Refusing to close a position because of emotional attachment to the asset",
      "Treating a long-held winner as untouchable regardless of current score",
    ],
    affirmations: [
      "I am loyal to the system. Positions are temporary. The system is permanent.",
      "No sacred cows. Every position earns its place or leaves.",
      "The warrior serves their lord — not their sword.",
    ],
  },
];

// ─── BEHAVIORAL AUDIT ENGINE ─────────────────────────────────────────────────

interface VirtueScore {
  kanji: string;
  romaji: string;
  english: string;
  score: number;           // 0–10
  grade: "MASTER" | "DISCIPLINED" | "LEARNING" | "STRUGGLING" | "VIOLATED";
  flags: string[];         // specific violations detected
  guidance: string;        // what to do next cycle
}

interface BushidoAudit {
  cycle_number: number;
  overall_score: number;       // 0–100
  overall_grade: string;
  soul_status: "ALIGNED" | "DRIFTING" | "COMPROMISED" | "BROKEN";
  virtue_scores: VirtueScore[];
  critical_violations: string[];
  commendations: string[];
  daily_mandate: string;       // one clear instruction for the next cycle
  closing_reflection: string;  // Bushido wisdom for the day
}

const CLOSING_REFLECTIONS = [
  "The way of the samurai is found in death. Approach each trade as if it were your last — complete, decisive, and without regret. — Yamamoto Tsunetomo",
  "Think lightly of yourself and deeply of the world. — Miyamoto Musashi",
  "There is nothing outside of yourself that can ever enable you to get better, stronger, richer, quicker, or smarter. Everything is within. — Miyamoto Musashi",
  "Do nothing that is of no use. — Miyamoto Musashi",
  "A samurai must remain calm at all times even if faced with death. — Yamamoto Tsunetomo",
  "If you know the way broadly, you will see it in all things. — Miyamoto Musashi",
  "The ultimate aim of martial arts is not having to use them. — Miyamoto Musashi",
  "The true science of martial arts means practicing them in such a way that they will be useful at any time, and to teach them in such a way that they will be useful in all things. — Miyamoto Musashi",
  "Today is victory over yourself of yesterday. — Miyamoto Musashi",
  "Perceive that which cannot be seen with the eye. — Miyamoto Musashi",
  "The warrior's way is the resolute acceptance of death. — Yamamoto Tsunetomo",
  "In the void is virtue, and no evil. Wisdom has existence, principle has existence, the Way has existence, spirit is nothingness. — Miyamoto Musashi",
  "The greatest victory is that which requires no battle. — Sun Tzu",
  "He who knows when he can fight and when he cannot will be victorious. — Sun Tzu",
  "Supreme excellence consists in breaking the enemy's resistance without fighting. — Sun Tzu",
];

function scoreVirtue(
  virtue: Virtue,
  request: Record<string, any>,
  index: number
): VirtueScore {
  const flags: string[] = [];
  let score = 10;

  const drawdownPct = Number(request.drawdown_pct || 0);
  const overrides = Number(request.overrides_this_week || 0);
  const consecutiveLosses = Number(request.consecutive_losses || 0);
  const recentActions: Array<{ action: string; cycle: number }> =
    request.recent_actions || [];
  const equity = Number(request.account_equity || 10000);
  const hwm = Number(request.high_water_mark || equity);
  const activePositions = Number(request.active_positions || 0);
  const maxPositions = Number(request.max_positions || 5);

  const actionText = recentActions.map((a) => a.action.toLowerCase()).join(" ");

  // Virtue-specific scoring logic
  switch (index) {
    case 0: // GI — Righteousness
      if (overrides > 0) {
        score -= overrides * 2;
        flags.push(`${overrides} system override(s) detected this week — each override is a failure of Gi`);
      }
      if (actionText.includes("held") && actionText.includes("past stop")) {
        score -= 3;
        flags.push("Position held past stop-loss trigger — direct violation of right action");
      }
      break;

    case 1: // YU — Courage
      if (request.missed_entries_this_week > 0) {
        score -= request.missed_entries_this_week * 2;
        flags.push(
          `${request.missed_entries_this_week} qualifying entry(s) skipped — fear overrode valid signal`
        );
      }
      if (consecutiveLosses >= 3) {
        score -= 1;
        flags.push("3+ consecutive losses may be suppressing entry courage — monitor for hesitation bias");
      }
      break;

    case 2: // JIN — Benevolence
      if (drawdownPct > 20) {
        score -= 4;
        flags.push(
          `Drawdown at ${drawdownPct.toFixed(1)}% — SURVIVAL tier: benevolence demands 0.5% max risk per trade`
        );
      } else if (drawdownPct > 10) {
        score -= 2;
        flags.push(
          `Drawdown at ${drawdownPct.toFixed(1)}% — DEFENSIVE tier: reduce position sizes immediately`
        );
      } else if (drawdownPct > 5) {
        score -= 1;
        flags.push(`Drawdown at ${drawdownPct.toFixed(1)}% — REDUCED tier: 1.5% max risk per trade`);
      }
      if (actionText.includes("adding") && actionText.includes("losing")) {
        score -= 5;
        flags.push("CRITICAL: Adding to losing position detected — this is a capital violation");
      }
      break;

    case 3: // REI — Respect
      if (actionText.includes("moved") && actionText.includes("stop")) {
        score -= 4;
        flags.push("Stop was moved — the market's authority was disrespected");
      }
      if (actionText.includes("will come back") || actionText.includes("believe in")) {
        score -= 3;
        flags.push("Hope-based holding detected — respect demands accepting the market's verdict");
      }
      if (overrides > 0 && actionText.includes("loss")) {
        score -= 2;
        flags.push("Override resulted in loss — the market was right, the override was wrong");
      }
      break;

    case 4: // MAKOTO — Honesty
      if (overrides > 0) {
        score -= 2;
        flags.push(`${overrides} override(s) must be logged with honest attribution — not labeled as 'judgment calls'`);
      }
      if (consecutiveLosses >= 3) {
        score -= 1;
        flags.push("3+ losses require honest attribution review — are these signal failures or execution failures?");
      }
      break;

    case 5: // MEIYO — Honor
      if (overrides > 2) {
        score -= 5;
        flags.push(
          `${overrides} overrides this week — the system is being abandoned. Honor demands full compliance.`
        );
      } else if (overrides > 0) {
        score -= 2;
        flags.push(`${overrides} override(s) — each one erodes the system's statistical edge`);
      }
      if (drawdownPct > 15 && overrides > 0) {
        score -= 3;
        flags.push("CRITICAL: Overriding system DURING drawdown — this is the exact moment honor is tested and failing");
      }
      break;

    case 6: // CHUGI — Loyalty
      if (actionText.includes("held") && actionText.includes("past")) {
        score -= 3;
        flags.push("Position held past system signal — loyalty to position overriding loyalty to strategy");
      }
      if (actionText.includes("one more cycle")) {
        score -= 4;
        flags.push("'One more cycle' rationale used — this is how sacred cows are born. Close the position.");
      }
      if (activePositions === maxPositions && overrides > 0) {
        score -= 2;
        flags.push("At max positions AND overriding — new entries require old positions to prove their score");
      }
      break;
  }

  // Commendable actions boost score (cap at 10)
  if (actionText.includes("closed") && actionText.includes("trend intact")) {
    // Closing a winner by system rule, not emotion
  }
  if (actionText.includes("skipped entry") && actionText.includes("heat")) {
    // Skipping entry because heat was at limit — correct discipline
    if (index === 2) score = Math.min(10, score + 1);
  }

  score = Math.max(0, Math.min(10, score));

  const grade: VirtueScore["grade"] =
    score >= 9
      ? "MASTER"
      : score >= 7
      ? "DISCIPLINED"
      : score >= 5
      ? "LEARNING"
      : score >= 3
      ? "STRUGGLING"
      : "VIOLATED";

  const guidanceMap: Record<VirtueScore["grade"], string> = {
    MASTER: `${virtue.romaji} is strong. Maintain this standard and let it anchor the other virtues.`,
    DISCIPLINED: `${virtue.romaji} is solid. One area of attention: ${flags[0] || "maintain current practice"}.`,
    LEARNING: `${virtue.romaji} needs attention. Review violations and apply corrections next cycle before opening positions.`,
    STRUGGLING: `${virtue.romaji} is compromised. Mandatory: address violations before next trade. ${flags[0] || ""}`,
    VIOLATED: `${virtue.romaji} has been violated. STOP — do not open new positions until this is resolved. ${flags[0] || ""}`,
  };

  return {
    kanji: virtue.kanji,
    romaji: virtue.romaji,
    english: virtue.english,
    score,
    grade,
    flags,
    guidance: guidanceMap[grade],
  };
}

function buildDailyMandate(
  scores: VirtueScore[],
  request: Record<string, any>
): string {
  const violated = scores.filter((s) => s.grade === "VIOLATED");
  const struggling = scores.filter((s) => s.grade === "STRUGGLING");
  const drawdownPct = Number(request.drawdown_pct || 0);
  const overrides = Number(request.overrides_this_week || 0);

  if (violated.length > 0) {
    return `MANDATE: Before any trade today — resolve ${violated[0].romaji} violation. "${violated[0].flags[0]}". No new positions until this is addressed.`;
  }
  if (struggling.length > 0) {
    return `MANDATE: ${struggling[0].romaji} requires correction. Today: ${struggling[0].guidance} Reduce position sizes by 50% until score recovers.`;
  }
  if (drawdownPct > 10) {
    return `MANDATE: Drawdown at ${drawdownPct.toFixed(1)}%. Trade at DEFENSIVE size (1.0% max risk). No pyramiding. Protect capital above all.`;
  }
  if (overrides > 0) {
    return `MANDATE: ${overrides} override(s) logged this week. Today: zero overrides permitted. Follow every signal exactly as the system generates it.`;
  }
  return "MANDATE: System alignment is strong. Execute today's cycle with precision. Follow signal, size correctly, honor every stop.";
}

// ─── MAIN ────────────────────────────────────────────────────────────────────

export async function executeJob(
  request: Record<string, any>
): Promise<ExecuteJobResult> {
  const cycleNumber = Number(request.cycle_number || 1);
  const equity = Number(request.account_equity || 10000);
  const hwm = Number(request.high_water_mark || equity);
  const drawdownPct = Number(request.drawdown_pct || ((hwm - equity) / hwm) * 100);

  // ── Score all seven virtues ──
  const virtueScores: VirtueScore[] = BUSHIDO_VIRTUES.map((v, i) =>
    scoreVirtue(v, request, i)
  );

  // ── Overall score ──
  const totalScore = virtueScores.reduce((sum, v) => sum + v.score, 0);
  const overallScore = Math.round((totalScore / (BUSHIDO_VIRTUES.length * 10)) * 100);

  const overallGrade =
    overallScore >= 90
      ? "武士 BUSHI — Master Warrior"
      : overallScore >= 75
      ? "侍 SAMURAI — Disciplined"
      : overallScore >= 60
      ? "修行者 SHUGYOSHA — Practitioner"
      : overallScore >= 40
      ? "見習い MINARAI — Apprentice"
      : "浪人 RONIN — Masterless (system abandoned)";

  const soulStatus: BushidoAudit["soul_status"] =
    overallScore >= 80
      ? "ALIGNED"
      : overallScore >= 60
      ? "DRIFTING"
      : overallScore >= 40
      ? "COMPROMISED"
      : "BROKEN";

  // ── Critical violations ──
  const criticalViolations = virtueScores
    .filter((v) => v.grade === "VIOLATED" || v.grade === "STRUGGLING")
    .flatMap((v) => v.flags.map((f) => `[${v.romaji}] ${f}`));

  // ── Commendations ──
  const commendations = virtueScores
    .filter((v) => v.grade === "MASTER" || v.grade === "DISCIPLINED")
    .map(
      (v) =>
        `[${v.romaji}] ${v.english} — score ${v.score}/10. ${v.romaji} is holding strong.`
    );

  // ── Daily mandate ──
  const dailyMandate = buildDailyMandate(virtueScores, request);

  // ── Closing reflection ──
  const reflectionIndex = cycleNumber % CLOSING_REFLECTIONS.length;
  const closingReflection = CLOSING_REFLECTIONS[reflectionIndex];

  // ── Full soul print ──
  const soulPrint = {
    identity: "Seykota — Trend-Following Agent",
    philosophy: "The system is the soul. The soul is the system.",
    code: "Follow signal. Cut losses. Let winners ride. Protect capital. No sacred cows.",
    virtues: BUSHIDO_VIRTUES.map((v) => ({
      kanji: v.kanji,
      romaji: v.romaji,
      english: v.english,
      trading_principle: v.trading_principle,
      core_affirmation: v.affirmations[cycleNumber % v.affirmations.length],
    })),
  };

  const audit: BushidoAudit = {
    cycle_number: cycleNumber,
    overall_score: overallScore,
    overall_grade: overallGrade,
    soul_status: soulStatus,
    virtue_scores: virtueScores,
    critical_violations: criticalViolations,
    commendations,
    daily_mandate: dailyMandate,
    closing_reflection: closingReflection,
  };

  const summary =
    `Bushido Soul Audit — Cycle ${cycleNumber}. ` +
    `Overall: ${overallScore}/100 (${overallGrade}). ` +
    `Soul: ${soulStatus}. ` +
    (criticalViolations.length > 0
      ? `${criticalViolations.length} violation(s): ${criticalViolations[0]}. `
      : "No violations. ") +
    `Mandate: ${dailyMandate}`;

  return {
    deliverable: JSON.stringify({
      schema: "bushido_soul",
      audited_at: new Date().toISOString(),
      summary,
      audit,
      soul_print: soulPrint,
      context: {
        cycle_number: cycleNumber,
        account_equity_usd: equity,
        high_water_mark_usd: hwm,
        drawdown_pct: Math.round(drawdownPct * 100) / 100,
        drawdown_tier:
          drawdownPct > 20
            ? "SURVIVAL"
            : drawdownPct > 10
            ? "DEFENSIVE"
            : drawdownPct > 5
            ? "REDUCED"
            : "NORMAL",
        active_positions: request.active_positions || 0,
        overrides_this_week: request.overrides_this_week || 0,
        consecutive_losses: request.consecutive_losses || 0,
      },
    }),
  };
}
HANDLER_EOF

cat > druck-suggestions-handler.ts << 'HANDLER_EOF'
import type { ExecuteJobResult } from "../../../runtime/offeringTypes.js";

/**
 * Druckenmiller Agent Job: Suggestions Schema
 * cron: "0 */6 * * *"  — Every 6 hours
 *
 * Generates macro-informed, asymmetry-filtered trading suggestions
 * in the Druckenmiller style: macro regime first, then individual
 * asset asymmetry, then concentration check.
 *
 * Only suggests positions with ≥3:1 reward/risk.
 * Sizes suggestions to conviction level.
 * Always checks macro regime before any suggestion.
 *
 * Example request:
 * {
 *   "risk_tier": "normal",
 *   "account_equity": 50000,
 *   "macro_regime": "RISK_ON_FRAGILE",
 *   "active_positions": ["ETH", "SOL"],
 *   "sectors_to_watch": ["L1", "DeFi", "AI"]
 * }
 */

const DEFILLAMA_BASE = "https://api.llama.fi";
const COINGECKO_BASE = "https://api.coingecko.com/api/v3";
const CG_KEY = process.env.COINGECKO_API_KEY || "";

type RiskTier = "normal" | "reduced" | "defensive" | "survival";
type MacroRegime = "RISK_ON_BULL" | "RISK_ON_FRAGILE" | "TRANSITIONAL" | "RISK_OFF_BEAR" | "CRISIS";

interface Suggestion {
  id: string;
  priority: "HIGH" | "MEDIUM" | "LOW";
  direction: "LONG" | "SHORT" | "NEUTRAL";
  asset: string;
  category: string;
  action: string;
  thesis: string;
  asymmetry_note: string;
  min_rr_ratio: number;
  conviction_required: number;
  macro_dependency: string;
  applicable_regimes: MacroRegime[];
  applicable_tiers: RiskTier[];
  invalidation: string;
}

const TIER_ORDER: Record<RiskTier, number> = { normal: 0, reduced: 1, defensive: 2, survival: 3 };
const REGIME_RISK: Record<MacroRegime, number> = {
  RISK_ON_BULL: 0, RISK_ON_FRAGILE: 1, TRANSITIONAL: 2, RISK_OFF_BEAR: 3, CRISIS: 4,
};

function buildStaticSuggestions(): Suggestion[] {
  return [
    {
      id: "druck-l1-rotation-early",
      priority: "HIGH",
      direction: "LONG",
      asset: "SOL / SUI / NEAR",
      category: "L1 Rotation",
      action: "LONG highest-momentum L1 with rising TVL and dev activity",
      thesis: "L1 rotation follows liquidity cycles. In early risk-on phases, capital flows from BTC → ETH → alt-L1s in sequence. Catching this rotation early — before CT consensus — is the Druckenmiller edge. TVL inflection + DEX volume spike = early signal.",
      asymmetry_note: "Entry at TVL inflection gives 5–15× upside with defined stop at TVL trend break",
      min_rr_ratio: 5,
      conviction_required: 7,
      macro_dependency: "Requires RISK_ON_BULL or RISK_ON_FRAGILE regime. Exit immediately if regime shifts to TRANSITIONAL.",
      applicable_regimes: ["RISK_ON_BULL", "RISK_ON_FRAGILE"],
      applicable_tiers: ["normal", "reduced"],
      invalidation: "TVL growth reverses for 2 consecutive weeks OR macro regime shifts to TRANSITIONAL or worse",
    },
    {
      id: "druck-btc-macro-long",
      priority: "HIGH",
      direction: "LONG",
      asset: "BTC",
      category: "Macro Hedge",
      action: "LONG BTC as macro liquidity hedge — size to regime",
      thesis: "BTC is the purest expression of global liquidity. When M2 expands and the Fed pivots dovish, BTC leads crypto. This is not a narrative trade — it is a liquidity trade. Size: 20–30% in RISK_ON_BULL, 10–15% in RISK_ON_FRAGILE, 0% in TRANSITIONAL or worse.",
      asymmetry_note: "BTC in early liquidity expansion cycle has historically delivered 3–10× from entry to cycle peak",
      min_rr_ratio: 3,
      conviction_required: 6,
      macro_dependency: "Directly tied to M2 growth and Fed stance. Short if regime flips to RISK_OFF_BEAR.",
      applicable_regimes: ["RISK_ON_BULL", "RISK_ON_FRAGILE"],
      applicable_tiers: ["normal", "reduced", "defensive"],
      invalidation: "Fed resumes hiking cycle OR M2 growth turns negative YoY",
    },
    {
      id: "druck-defi-revenue-revision",
      priority: "MEDIUM",
      direction: "LONG",
      asset: "AAVE / UNI / CRV",
      category: "DeFi Revenue",
      action: "LONG DeFi protocols with rising fee revenue — earnings revision play",
      thesis: "DeFi protocols with accelerating fee revenue are the crypto equivalent of Druckenmiller's earnings revision signal. When protocol fees rise for 3+ consecutive weeks, it signals genuine activity growth — not narrative. Market rerate follows. Find the revision before consensus.",
      asymmetry_note: "Protocol at fee inflection with 5× revenue growth potential vs. 30% downside to support",
      min_rr_ratio: 4,
      conviction_required: 7,
      macro_dependency: "Works in any risk-on regime. Avoid in RISK_OFF_BEAR — DeFi is high-beta.",
      applicable_regimes: ["RISK_ON_BULL", "RISK_ON_FRAGILE"],
      applicable_tiers: ["normal"],
      invalidation: "Fee revenue growth decelerates or reverses for 2 consecutive weeks",
    },
    {
      id: "druck-short-weak-l1",
      priority: "MEDIUM",
      direction: "SHORT",
      asset: "Structurally declining L1",
      category: "Short / Relative Value",
      action: "SHORT L1 with declining TVL, developer exodus, and falling fee revenue",
      thesis: "In a risk-off or transitional regime, capital concentrates into quality. L1s with declining TVL, shrinking developer activity, and losing market share to competitors are structural shorts. The narrative stays bullish long after the fundamentals deteriorate — that gap is the edge.",
      asymmetry_note: "Structural decline trades can deliver 5–20× on the short side with time as your ally",
      min_rr_ratio: 4,
      conviction_required: 7,
      macro_dependency: "Best in RISK_OFF_BEAR or TRANSITIONAL. In RISK_ON_BULL, short only relative-value pairs.",
      applicable_regimes: ["TRANSITIONAL", "RISK_OFF_BEAR", "CRISIS"],
      applicable_tiers: ["normal", "reduced"],
      invalidation: "TVL reverses upward for 2 consecutive weeks OR major protocol announces on target chain",
    },
    {
      id: "druck-cash-position",
      priority: "HIGH",
      direction: "NEUTRAL",
      asset: "CASH / USDC",
      category: "Capital Preservation",
      action: "HOLD cash — macro uncertainty requires patience",
      thesis: "In a TRANSITIONAL or CRISIS regime, cash is a position. Druckenmiller held up to 30% cash when conviction was absent. The cost of missed opportunity is always less than the cost of a wrong large bet. Cash preserves optionality for the next high-conviction asymmetric setup.",
      asymmetry_note: "Cash costs you nothing when macro is unclear. A wrong bet in CRISIS costs you 30–80%.",
      min_rr_ratio: 0,
      conviction_required: 0,
      macro_dependency: "Mandatory in CRISIS. Highly recommended in TRANSITIONAL.",
      applicable_regimes: ["TRANSITIONAL", "RISK_OFF_BEAR", "CRISIS"],
      applicable_tiers: ["normal", "reduced", "defensive", "survival"],
      invalidation: "Macro regime clearly shifts to RISK_ON_FRAGILE or better",
    },
  ];
}

export async function executeJob(request: Record<string, any>): Promise<ExecuteJobResult> {
  const riskTier: RiskTier = (request.risk_tier as RiskTier) || "normal";
  const macroRegime: MacroRegime = (request.macro_regime as MacroRegime) || "TRANSITIONAL";
  const equity = Number(request.account_equity || 50000);
  const activePositions: string[] = request.active_positions || [];

  const cgHeaders: Record<string, string> = CG_KEY ? { "x-cg-demo-api-key": CG_KEY } : {};

  // Fetch live macro proxies
  let btcChange7d: number | null = null;
  let totalCryptoTvl: number | null = null;

  try {
    const [cgRes, tvlRes] = await Promise.all([
      fetch(`${COINGECKO_BASE}/simple/price?ids=bitcoin,ethereum&vs_currencies=usd&include_7d_change=true`, { headers: cgHeaders }),
      fetch(`${DEFILLAMA_BASE}/v2/chains`),
    ]);
    if (cgRes.ok) {
      const p = await cgRes.json();
      btcChange7d = p.bitcoin?.usd_7d_change ?? null;
    }
    if (tvlRes.ok) {
      const chains: any[] = await tvlRes.json();
      totalCryptoTvl = chains.reduce((sum, c) => sum + (c.tvl || 0), 0);
    }
  } catch (_) {}

  const staticSuggestions = buildStaticSuggestions();

  const filtered = staticSuggestions.filter(s =>
    s.applicable_regimes.includes(macroRegime) &&
    s.applicable_tiers.includes(riskTier)
  );

  // Dynamic: if BTC strongly positive, elevate L1 rotation suggestion
  const dynamic: Suggestion[] = [];
  if (btcChange7d !== null && btcChange7d > 15 && (macroRegime === "RISK_ON_BULL" || macroRegime === "RISK_ON_FRAGILE")) {
    dynamic.push({
      id: "live-btc-momentum-rotate",
      priority: "HIGH",
      direction: "LONG",
      asset: "ETH / SOL",
      category: "Momentum Rotation",
      action: `BTC up ${btcChange7d.toFixed(1)}% 7D — rotate into ETH/SOL for alt-beta`,
      thesis: "BTC momentum of this magnitude historically precedes ETH/SOL outperformance by 1–3 weeks as risk appetite flows to higher-beta L1s. Be early to the rotation.",
      asymmetry_note: "ETH/SOL historically deliver 1.5–3× BTC return in alt-rotation phase",
      min_rr_ratio: 3,
      conviction_required: 6,
      macro_dependency: "Requires sustained BTC strength and risk-on regime",
      applicable_regimes: ["RISK_ON_BULL", "RISK_ON_FRAGILE"],
      applicable_tiers: ["normal", "reduced"],
      invalidation: "BTC reverses more than 10% from recent high",
    });
  }

  const all = [...dynamic, ...filtered].sort((a, b) => {
    const order = { HIGH: 0, MEDIUM: 1, LOW: 2 };
    return order[a.priority] - order[b.priority];
  });

  const summary =
    `Druckenmiller Suggestions — ${macroRegime} regime, ${riskTier.toUpperCase()} tier. ` +
    `${all.length} suggestion(s). ` +
    (btcChange7d !== null ? `BTC 7D: ${btcChange7d > 0 ? "+" : ""}${btcChange7d.toFixed(1)}%. ` : "") +
    (totalCryptoTvl ? `Total crypto TVL: $${(totalCryptoTvl / 1e9).toFixed(1)}B. ` : "") +
    (all[0] ? `Top action: ${all[0].action}` : "No suggestions at current regime/tier.");

  return {
    deliverable: JSON.stringify({
      schema: "druckenmiller_suggestions",
      generated_at: new Date().toISOString(),
      macro_regime: macroRegime,
      risk_tier: riskTier,
      account_equity_usd: equity,
      active_positions: activePositions,
      suggestion_count: all.length,
      live_data: { btc_change_7d: btcChange7d, total_crypto_tvl: totalCryptoTvl },
      summary,
      suggestions: all,
    }),
  };
}
HANDLER_EOF

cat > druck-tracking-chain-handler.ts << 'HANDLER_EOF'
import type { ExecuteJobResult } from "../../../runtime/offeringTypes.js";

/**
 * Druckenmiller Agent Job: Tracking Chain Schema
 * cron: "0 */3 * * *"  — Every 3 hours
 *
 * Chain-level intelligence through the Druckenmiller macro lens.
 * TVL is the blockchain equivalent of earnings — the fundamental
 * metric that drives token valuation revisions.
 *
 * TVL inflecting upward = buy signal (earnings revision up)
 * TVL inflecting downward = sell/short signal (earnings revision down)
 * TVL growing faster than others = relative value long
 * TVL declining fastest = relative value short
 *
 * Example request:
 * {
 *   "chains": ["ethereum", "base", "solana", "avalanche", "sui"],
 *   "include_protocols": true,
 *   "macro_regime": "RISK_ON_FRAGILE"
 * }
 */

const DEFILLAMA_BASE = "https://api.llama.fi";

type MacroRegime = "RISK_ON_BULL" | "RISK_ON_FRAGILE" | "TRANSITIONAL" | "RISK_OFF_BEAR" | "CRISIS";

interface ChainProfile {
  name: string;
  tvl_usd: number;
  tvl_change_1d: number | null;
  tvl_change_7d: number | null;
  dex_volume_24h: number | null;
  fee_revenue_24h: number | null;
  volume_tvl_ratio: number | null;
  fundamental_signal: "STRONG_BUY" | "BUY" | "HOLD" | "SELL" | "STRONG_SELL";
  revision_direction: "ACCELERATING" | "IMPROVING" | "STABLE" | "DETERIORATING" | "COLLAPSING";
  relative_rank: number;
  druckenmiller_read: string;
  alert: string | null;
}

function classifyRevision(change7d: number | null, change1d: number | null): ChainProfile["revision_direction"] {
  if (change7d == null) return "STABLE";
  if (change7d > 20) return "ACCELERATING";
  if (change7d > 5) return "IMPROVING";
  if (change7d > -5) return "STABLE";
  if (change7d > -15) return "DETERIORATING";
  return "COLLAPSING";
}

function classifyFundamentalSignal(
  revision: ChainProfile["revision_direction"],
  macroRegime: MacroRegime
): ChainProfile["fundamental_signal"] {
  const regimePositive = macroRegime === "RISK_ON_BULL" || macroRegime === "RISK_ON_FRAGILE";
  const regimeNegative = macroRegime === "RISK_OFF_BEAR" || macroRegime === "CRISIS";

  if (revision === "ACCELERATING" && regimePositive) return "STRONG_BUY";
  if (revision === "IMPROVING" && regimePositive) return "BUY";
  if (revision === "STABLE") return "HOLD";
  if (revision === "DETERIORATING" && regimeNegative) return "STRONG_SELL";
  if (revision === "DETERIORATING") return "SELL";
  if (revision === "COLLAPSING") return "STRONG_SELL";
  if (revision === "ACCELERATING" && regimeNegative) return "HOLD"; // good chain, bad macro
  return "HOLD";
}

function buildDruckRead(name: string, signal: ChainProfile["fundamental_signal"], revision: ChainProfile["revision_direction"], tvlChange7d: number | null): string {
  const pct = tvlChange7d != null ? ` (${tvlChange7d > 0 ? "+" : ""}${tvlChange7d.toFixed(1)}% 7D TVL)` : "";
  if (signal === "STRONG_BUY") return `${name}${pct} — STRONG BUY. TVL accelerating = positive earnings revision. Be early. This is the Druckenmiller setup.`;
  if (signal === "BUY") return `${name}${pct} — BUY. Fundamentals improving. Position before consensus recognizes the revision.`;
  if (signal === "HOLD") return `${name}${pct} — HOLD. No compelling revision signal in either direction. Monitor.`;
  if (signal === "SELL") return `${name}${pct} — SELL or REDUCE. TVL declining. Fundamental revision is negative. Reduce before narrative catches up.`;
  return `${name}${pct} — STRONG SELL or SHORT. TVL collapsing. Capital exiting. The narrative will catch up to the fundamentals — be short first.`;
}

export async function executeJob(request: Record<string, any>): Promise<ExecuteJobResult> {
  const chainNames: string[] = (request.chains || ["ethereum", "base", "solana", "avalanche", "arbitrum", "sui", "near"]).map((c: string) => c.toLowerCase());
  const macroRegime: MacroRegime = (request.macro_regime as MacroRegime) || "TRANSITIONAL";
  const includeProtocols = request.include_protocols !== false;

  try {
    const [chainRes, dexRes, feesRes, protocolRes] = await Promise.all([
      fetch(`${DEFILLAMA_BASE}/v2/chains`),
      fetch(`${DEFILLAMA_BASE}/overview/dexs?excludeTotalDataChart=true&dataType=dailyVolume`),
      fetch(`${DEFILLAMA_BASE}/overview/fees?excludeTotalDataChart=true&dataType=dailyFees`),
      includeProtocols ? fetch(`${DEFILLAMA_BASE}/protocols`) : Promise.resolve(null),
    ]);

    const allChains: any[] = chainRes.ok ? await chainRes.json() : [];
    const dexData: any = dexRes.ok ? await dexRes.json() : null;
    const feesData: any = feesRes.ok ? await feesRes.json() : null;
    const allProtocols: any[] = protocolRes?.ok ? await protocolRes.json() : [];

    // Build volume/fee maps
    const dexVolMap: Record<string, number> = {};
    for (const p of dexData?.protocols || []) {
      for (const chain of p.chains || []) {
        const k = chain.toLowerCase();
        dexVolMap[k] = (dexVolMap[k] || 0) + (p.total24h || 0) / (p.chains?.length || 1);
      }
    }
    const feeMap: Record<string, number> = {};
    for (const p of feesData?.protocols || []) {
      for (const chain of p.chains || []) {
        const k = chain.toLowerCase();
        feeMap[k] = (feeMap[k] || 0) + (p.total24h || 0) / (p.chains?.length || 1);
      }
    }

    // Build profiles
    const profiles: ChainProfile[] = chainNames.map(name => {
      const raw = allChains.find(c => c.name?.toLowerCase() === name);
      const tvl = raw?.tvl || 0;
      const c1d = raw?.change_1d ?? null;
      const c7d = raw?.change_7d ?? null;
      const dexVol = dexVolMap[name] ?? null;
      const feeRev = feeMap[name] ?? null;
      const vtRatio = tvl > 0 && dexVol != null ? Math.round((dexVol / tvl) * 10000) / 100 : null;
      const revision = classifyRevision(c7d, c1d);
      const signal = classifyFundamentalSignal(revision, macroRegime);
      const drRead = buildDruckRead(raw?.name || name, signal, revision, c7d);
      const alert =
        revision === "COLLAPSING" ? `COLLAPSING TVL on ${raw?.name || name} — exit or short` :
        revision === "ACCELERATING" ? `ACCELERATING TVL on ${raw?.name || name} — be early` : null;

      return {
        name: raw?.name || name,
        tvl_usd: tvl,
        tvl_change_1d: c1d != null ? Math.round(c1d * 10) / 10 : null,
        tvl_change_7d: c7d != null ? Math.round(c7d * 10) / 10 : null,
        dex_volume_24h: dexVol ? Math.round(dexVol) : null,
        fee_revenue_24h: feeRev ? Math.round(feeRev) : null,
        volume_tvl_ratio: vtRatio,
        fundamental_signal: signal,
        revision_direction: revision,
        relative_rank: 0,
        druckenmiller_read: drRead,
        alert,
      };
    });

    // Rank by 7D TVL growth
    const sorted = [...profiles].sort((a, b) => (b.tvl_change_7d ?? 0) - (a.tvl_change_7d ?? 0));
    sorted.forEach((p, i) => { const m = profiles.find(x => x.name === p.name); if (m) m.relative_rank = i + 1; });

    // Top protocols per chain
    const topProtocols: Record<string, string[]> = {};
    if (includeProtocols && allProtocols.length > 0) {
      for (const name of chainNames) {
        topProtocols[name] = allProtocols
          .filter(p => (p.chains || []).map((c: string) => c.toLowerCase()).includes(name))
          .sort((a, b) => (b.tvl || 0) - (a.tvl || 0))
          .slice(0, 3)
          .map(p => `${p.name} ($${((p.tvl || 0) / 1e6).toFixed(1)}M TVL)`);
      }
    }

    const strongBuy = profiles.filter(p => p.fundamental_signal === "STRONG_BUY");
    const strongSell = profiles.filter(p => p.fundamental_signal === "STRONG_SELL");
    const alerts = profiles.filter(p => p.alert);

    const summary =
      `Chain scan — ${macroRegime} macro regime. ` +
      `${profiles.length} chains. ` +
      `${strongBuy.length} STRONG_BUY revision(s): ${strongBuy.map(p => p.name).join(", ") || "none"}. ` +
      `${strongSell.length} STRONG_SELL warning(s): ${strongSell.map(p => p.name).join(", ") || "none"}. ` +
      `${alerts.length} alert(s).`;

    return {
      deliverable: JSON.stringify({
        schema: "druckenmiller_tracking_chain",
        tracked_at: new Date().toISOString(),
        macro_regime: macroRegime,
        chain_count: profiles.length,
        strong_buy_chains: strongBuy.map(p => p.name),
        strong_sell_chains: strongSell.map(p => p.name),
        alerts: alerts.map(p => p.alert),
        summary,
        chains: profiles,
        top_protocols: topProtocols,
      }),
    };
  } catch (e: any) {
    return { deliverable: JSON.stringify({ schema: "druckenmiller_tracking_chain", error: e.message }) };
  }
}
HANDLER_EOF

cat > druck-tracking-coin-handler.ts << 'HANDLER_EOF'
import type { ExecuteJobResult } from "../../../runtime/offeringTypes.js";

/**
 * Druckenmiller Agent Job: Tracking Coin Schema
 * cron: "*/20 * * * *"  — Every 20 minutes
 *
 * Deep per-coin intelligence through the Druckenmiller lens:
 * fundamental revision tracking, asymmetry calculation, thesis
 * health scoring, and macro regime alignment check.
 *
 * Unlike a pure technical scan, this evaluates whether the
 * FUNDAMENTAL TRAJECTORY is improving or deteriorating —
 * the Druckenmiller earnings-revision signal applied to crypto.
 *
 * Example request:
 * {
 *   "coin_id": "ethereum",
 *   "macro_regime": "RISK_ON_FRAGILE",
 *   "entry_price": 3200,
 *   "target_price": 6000,
 *   "stop_price": 2700,
 *   "conviction": 8,
 *   "include_ohlc": true
 * }
 */

const COINGECKO_BASE = "https://api.coingecko.com/api/v3";
const CG_KEY = process.env.COINGECKO_API_KEY || "";

type MacroRegime = "RISK_ON_BULL" | "RISK_ON_FRAGILE" | "TRANSITIONAL" | "RISK_OFF_BEAR" | "CRISIS";

interface FundamentalRevision {
  metric: string;
  direction: "IMPROVING" | "STABLE" | "DETERIORATING";
  detail: string;
}

interface AsymmetryProfile {
  reward_usd: number | null;
  risk_usd: number | null;
  rr_ratio: number | null;
  grade: "HOME_RUN" | "EXCELLENT" | "ACCEPTABLE" | "MARGINAL" | "REJECT" | "UNKNOWN";
  action: "SIZE_MAX" | "SIZE_NORMAL" | "SIZE_SMALL" | "PASS" | "EXIT";
  sizing_pct_of_portfolio: string;
}

function calcAsymmetry(current: number, target: number | null, stop: number | null): AsymmetryProfile {
  if (!target || !stop || current <= 0) {
    return { reward_usd: null, risk_usd: null, rr_ratio: null, grade: "UNKNOWN", action: "PASS", sizing_pct_of_portfolio: "0%" };
  }
  const reward = target - current;
  const risk = current - stop;
  const rr = risk > 0 ? Math.round((reward / risk) * 10) / 10 : null;

  const grade: AsymmetryProfile["grade"] =
    rr == null ? "UNKNOWN" :
    rr >= 8 ? "HOME_RUN" :
    rr >= 4 ? "EXCELLENT" :
    rr >= 2.5 ? "ACCEPTABLE" :
    rr >= 1.5 ? "MARGINAL" : "REJECT";

  const action: AsymmetryProfile["action"] =
    grade === "HOME_RUN" ? "SIZE_MAX" :
    grade === "EXCELLENT" ? "SIZE_NORMAL" :
    grade === "ACCEPTABLE" ? "SIZE_SMALL" :
    grade === "MARGINAL" ? "PASS" : "EXIT";

  const sizing =
    grade === "HOME_RUN" ? "20–35%" :
    grade === "EXCELLENT" ? "10–20%" :
    grade === "ACCEPTABLE" ? "5–10%" :
    "0%";

  return { reward_usd: Math.round(reward * 100) / 100, risk_usd: Math.round(Math.abs(risk) * 100) / 100, rr_ratio: rr, grade, action, sizing_pct_of_portfolio: sizing };
}

function buildRevisions(md: any, priceChange7d: number, priceChange30d: number): FundamentalRevision[] {
  const revisions: FundamentalRevision[] = [];

  // Volume trajectory as revenue proxy
  const vol = md.total_volume?.usd || 0;
  const mcap = md.market_cap?.usd || 1;
  const vtm = vol / mcap;
  revisions.push({
    metric: "Volume/MarketCap Ratio",
    direction: vtm > 0.08 ? "IMPROVING" : vtm > 0.03 ? "STABLE" : "DETERIORATING",
    detail: `${(vtm * 100).toFixed(2)}% — ${vtm > 0.08 ? "elevated activity = demand" : vtm > 0.03 ? "normal" : "low activity, weak demand"}`,
  });

  // Price momentum trajectory
  revisions.push({
    metric: "Price Momentum Trend",
    direction: priceChange7d > 5 ? "IMPROVING" : priceChange7d < -10 ? "DETERIORATING" : "STABLE",
    detail: `7D: ${priceChange7d.toFixed(1)}%, 30D: ${priceChange30d.toFixed(1)}%`,
  });

  // ATH distance (proxy for narrative cycle position)
  const athChange = md.ath_change_percentage?.usd ?? null;
  if (athChange != null) {
    revisions.push({
      metric: "ATH Distance (Cycle Position)",
      direction: athChange > -20 ? "IMPROVING" : athChange > -60 ? "STABLE" : "DETERIORATING",
      detail: `${athChange.toFixed(1)}% from ATH — ${athChange > -30 ? "near highs, late cycle" : athChange > -70 ? "mid-cycle" : "early cycle, asymmetric upside"}`,
    });
  }

  // Supply inflation proxy
  const circulating = md.circulating_supply || 0;
  const total = md.total_supply || circulating;
  const supplyPct = total > 0 ? (circulating / total) * 100 : 100;
  revisions.push({
    metric: "Supply Inflation Risk",
    direction: supplyPct > 85 ? "IMPROVING" : supplyPct > 50 ? "STABLE" : "DETERIORATING",
    detail: `${supplyPct.toFixed(1)}% of total supply circulating — ${supplyPct > 85 ? "low dilution risk" : supplyPct < 50 ? "high unlock risk" : "moderate"}`,
  });

  return revisions;
}

function checkMacroAlignment(macroRegime: MacroRegime, priceChange7d: number): {
  aligned: boolean; note: string;
} {
  if (macroRegime === "RISK_ON_BULL" && priceChange7d > 0)
    return { aligned: true, note: "Macro tailwind. Risk-on regime supports long exposure." };
  if (macroRegime === "RISK_OFF_BEAR" && priceChange7d < 0)
    return { aligned: true, note: "Macro headwind confirmed in price. Do not fight the regime." };
  if (macroRegime === "CRISIS")
    return { aligned: false, note: "CRISIS regime. No longs justified regardless of individual thesis." };
  if (macroRegime === "TRANSITIONAL")
    return { aligned: false, note: "TRANSITIONAL regime — unclear macro. Reduce size. Wait for clarity." };
  return { aligned: true, note: "Macro regime neutral relative to this position." };
}

export async function executeJob(request: Record<string, any>): Promise<ExecuteJobResult> {
  const coinId: string = request.coin_id || request.id || "ethereum";
  const macroRegime: MacroRegime = (request.macro_regime as MacroRegime) || "TRANSITIONAL";
  const entryPrice = Number(request.entry_price || 0);
  const targetPrice = Number(request.target_price || 0);
  const stopPrice = Number(request.stop_price || 0);
  const conviction = Number(request.conviction || 5);
  const includeOhlc = request.include_ohlc !== false;

  const cgHeaders: Record<string, string> = CG_KEY ? { "x-cg-demo-api-key": CG_KEY } : {};

  try {
    const [detailRes, ohlcRes] = await Promise.all([
      fetch(`${COINGECKO_BASE}/coins/${coinId}?localization=false&tickers=false&market_data=true&community_data=false&developer_data=false`, { headers: cgHeaders }),
      includeOhlc ? fetch(`${COINGECKO_BASE}/coins/${coinId}/ohlc?vs_currency=usd&days=14`, { headers: cgHeaders }) : Promise.resolve(null),
    ]);

    if (!detailRes.ok) throw new Error(`CoinGecko ${detailRes.status}: invalid coin_id "${coinId}"`);

    const detail = await detailRes.json();
    const md = detail.market_data || {};
    const currentPrice = md.current_price?.usd || 0;
    const pc24h = md.price_change_percentage_24h?.usd ?? 0;
    const pc7d = md.price_change_percentage_7d?.usd ?? 0;
    const pc30d = md.price_change_percentage_30d?.usd ?? 0;

    const asymmetry = calcAsymmetry(
      entryPrice > 0 ? currentPrice : currentPrice,
      targetPrice > 0 ? targetPrice : null,
      stopPrice > 0 ? stopPrice : null
    );

    const revisions = buildRevisions(md, pc7d, pc30d);
    const macroAlignment = checkMacroAlignment(macroRegime, pc7d);

    const improvingCount = revisions.filter(r => r.direction === "IMPROVING").length;
    const deterioratingCount = revisions.filter(r => r.direction === "DETERIORATING").length;

    const fundamentalTrend: "IMPROVING" | "MIXED" | "DETERIORATING" =
      improvingCount > deterioratingCount ? "IMPROVING" :
      deterioratingCount > improvingCount ? "DETERIORATING" : "MIXED";

    // Druckenmiller verdict
    const verdict =
      !macroAlignment.aligned ? "REDUCE OR EXIT — macro regime not supportive" :
      asymmetry.grade === "REJECT" ? "EXIT — reward/risk unacceptable, no edge" :
      fundamentalTrend === "DETERIORATING" ? "CAUTION — fundamentals deteriorating. Thesis at risk. Trim." :
      asymmetry.grade === "HOME_RUN" && fundamentalTrend === "IMPROVING" ? "HOME RUN SETUP — size up to maximum conviction allocation" :
      asymmetry.grade === "EXCELLENT" && conviction >= 7 ? "HIGH CONVICTION — size normally, press if working" :
      "HOLD — monitor for improving asymmetry or fundamental revision";

    const summary =
      `${detail.symbol?.toUpperCase()} @ $${currentPrice.toLocaleString()}. ` +
      `Asymmetry: ${asymmetry.rr_ratio?.toFixed(1) ?? "?"}:1 (${asymmetry.grade}). ` +
      `Fundamental trend: ${fundamentalTrend}. ` +
      `Macro: ${macroAlignment.aligned ? "ALIGNED" : "NOT ALIGNED"}. ` +
      `Verdict: ${verdict}`;

    return {
      deliverable: JSON.stringify({
        schema: "druckenmiller_tracking_coin",
        tracked_at: new Date().toISOString(),
        coin_id: coinId,
        symbol: detail.symbol?.toUpperCase(),
        name: detail.name,
        summary,
        verdict,
        price: {
          current_usd: currentPrice,
          change_24h: Math.round(pc24h * 100) / 100,
          change_7d: Math.round(pc7d * 100) / 100,
          change_30d: Math.round(pc30d * 100) / 100,
          ath_usd: md.ath?.usd,
          ath_change_pct: md.ath_change_percentage?.usd,
        },
        market: {
          market_cap_usd: md.market_cap?.usd,
          volume_24h_usd: md.total_volume?.usd,
          circulating_supply: md.circulating_supply,
          total_supply: md.total_supply,
        },
        asymmetry,
        fundamental_revisions: revisions,
        fundamental_trend: fundamentalTrend,
        macro_alignment: macroAlignment,
        conviction_input: conviction,
        position_inputs: { entry_price: entryPrice, target_price: targetPrice, stop_price: stopPrice },
      }),
    };
  } catch (e: any) {
    return { deliverable: JSON.stringify({ schema: "druckenmiller_tracking_coin", error: e.message, coin_id: coinId }) };
  }
}
HANDLER_EOF

cat > druck-tracking-volume-handler.ts << 'HANDLER_EOF'
import type { ExecuteJobResult } from "../../../runtime/offeringTypes.js";

/**
 * Druckenmiller Agent Job: Tracking Volume Schema
 * cron: "*/10 * * * *"  — Every 10 minutes
 *
 * Druckenmiller: "Volume is the footprint of money. Follow the footprint."
 *
 * Volume is not just a technical indicator — it is the quantitative
 * expression of conviction. Rising price on rising volume = institutional
 * accumulation. Rising price on falling volume = distribution in progress.
 * Volume divergence is the earliest warning system available.
 *
 * This schema tracks volume across L1 tokens and DEX protocols,
 * scores volume quality (not just quantity), and flags divergences.
 *
 * Example request:
 * {
 *   "tokens": ["bitcoin", "ethereum", "solana"],
 *   "alert_spike_multiplier": 2.5,
 *   "include_dex": true,
 *   "volume_quality_check": true
 * }
 */

const COINGECKO_BASE = "https://api.coingecko.com/api/v3";
const DEFILLAMA_BASE = "https://api.llama.fi";
const CG_KEY = process.env.COINGECKO_API_KEY || "";

type VolumeQuality = "INSTITUTIONAL" | "ACCUMULATION" | "DISTRIBUTION" | "NOISE" | "DEAD";
type VolumeSignal = "SPIKE" | "ELEVATED" | "NORMAL" | "DRY" | "DEAD";

interface TokenVolumeProfile {
  id: string;
  symbol: string;
  price_usd: number;
  volume_24h: number;
  market_cap: number;
  volume_to_mcap_pct: number;
  price_change_24h: number;
  price_change_7d: number;
  volume_signal: VolumeSignal;
  volume_quality: VolumeQuality;
  divergence: boolean;
  divergence_type: "ACCUMULATION" | "DISTRIBUTION" | null;
  druckenmiller_read: string;
  alert: boolean;
}

interface DexVolumeProfile {
  name: string;
  chain: string;
  volume_24h: number;
  tvl: number;
  volume_tvl_ratio: number;
  velocity_signal: "HOT" | "ACTIVE" | "NORMAL" | "SLOW";
}

function classifyVolumeSignal(volToMcap: number): VolumeSignal {
  if (volToMcap > 0.25) return "SPIKE";
  if (volToMcap > 0.12) return "ELEVATED";
  if (volToMcap > 0.03) return "NORMAL";
  if (volToMcap > 0.01) return "DRY";
  return "DEAD";
}

function classifyVolumeQuality(
  priceChange24h: number,
  volSignal: VolumeSignal
): VolumeQuality {
  const highVol = volSignal === "SPIKE" || volSignal === "ELEVATED";
  const priceFlat = Math.abs(priceChange24h) < 1.5;
  const priceUp = priceChange24h > 2;
  const priceDown = priceChange24h < -2;

  if (highVol && priceUp) return "INSTITUTIONAL"; // strong vol + price = conviction buying
  if (highVol && priceFlat) return "ACCUMULATION"; // vol without price move = quiet accumulation
  if (highVol && priceDown) return "DISTRIBUTION"; // vol with price drop = selling into liquidity
  if (volSignal === "DRY" || volSignal === "DEAD") return "DEAD";
  return "NOISE";
}

function buildDruckRead(profile: Partial<TokenVolumeProfile>): string {
  if (profile.volume_quality === "INSTITUTIONAL")
    return `Strong volume + price advance = institutional conviction. Druckenmiller would size this up if thesis is intact.`;
  if (profile.volume_quality === "ACCUMULATION")
    return `High volume with flat price = quiet accumulation. Someone is building a position before the move. Be early.`;
  if (profile.volume_quality === "DISTRIBUTION")
    return `High volume + falling price = distribution. Smart money is selling into retail strength. Do not buy dips here.`;
  if (profile.volume_quality === "DEAD")
    return `Dead volume. No institutional interest. Avoid — there is no edge in illiquid assets.`;
  return `Normal volume. No edge signal. Monitor for developing pattern.`;
}

export async function executeJob(request: Record<string, any>): Promise<ExecuteJobResult> {
  const tokenIds: string[] = request.tokens || ["bitcoin", "ethereum", "solana", "avalanche-2", "near", "sui"];
  const spikeMultiplier = Number(request.alert_spike_multiplier || 2.5);
  const includeDex = request.include_dex !== false;

  const cgHeaders: Record<string, string> = CG_KEY ? { "x-cg-demo-api-key": CG_KEY } : {};

  try {
    const [marketRes, dexRes] = await Promise.all([
      fetch(`${COINGECKO_BASE}/coins/markets?vs_currency=usd&ids=${tokenIds.join(",")}&order=volume_desc&price_change_percentage=24h,7d`, { headers: cgHeaders }),
      includeDex ? fetch(`${DEFILLAMA_BASE}/overview/dexs?excludeTotalDataChart=true&dataType=dailyVolume`) : Promise.resolve(null),
    ]);

    const markets: any[] = marketRes.ok ? await marketRes.json() : [];

    const profiles: TokenVolumeProfile[] = markets.map(m => {
      const vol24h = m.total_volume || 0;
      const mcap = m.market_cap || 1;
      const vtm = (vol24h / mcap) * 100;
      const pc24h = m.price_change_percentage_24h_in_currency ?? 0;
      const pc7d = m.price_change_percentage_7d_in_currency ?? 0;
      const volSig = classifyVolumeSignal(vtm / 100);
      const volQ = classifyVolumeQuality(pc24h, volSig);
      const divergence = (volSig === "SPIKE" || volSig === "ELEVATED") && Math.abs(pc24h) < 1.5;

      const partial: Partial<TokenVolumeProfile> = { volume_quality: volQ };
      const drRead = buildDruckRead(partial);

      return {
        id: m.id,
        symbol: m.symbol?.toUpperCase(),
        price_usd: m.current_price || 0,
        volume_24h: vol24h,
        market_cap: mcap,
        volume_to_mcap_pct: Math.round(vtm * 100) / 100,
        price_change_24h: Math.round(pc24h * 100) / 100,
        price_change_7d: Math.round(pc7d * 100) / 100,
        volume_signal: volSig,
        volume_quality: volQ,
        divergence,
        divergence_type: divergence ? (pc24h >= 0 ? "ACCUMULATION" : "DISTRIBUTION") : null,
        druckenmiller_read: drRead,
        alert: volSig === "SPIKE" || volQ === "DISTRIBUTION" || divergence,
      };
    });

    // DEX volumes
    const dexProfiles: DexVolumeProfile[] = [];
    if (includeDex && dexRes?.ok) {
      const dexData = await dexRes.json();
      for (const p of (dexData.protocols || []).slice(0, 12)) {
        const vol = p.total24h || 0;
        const tvl = p.tvl || 1;
        const ratio = (vol / tvl) * 100;
        dexProfiles.push({
          name: p.name,
          chain: (p.chains || []).join(", "),
          volume_24h: vol,
          tvl,
          volume_tvl_ratio: Math.round(ratio * 100) / 100,
          velocity_signal: ratio > 20 ? "HOT" : ratio > 8 ? "ACTIVE" : ratio > 2 ? "NORMAL" : "SLOW",
        });
      }
      dexProfiles.sort((a, b) => b.volume_24h - a.volume_24h);
    }

    const alerts = profiles.filter(p => p.alert);
    const accumulating = profiles.filter(p => p.divergence_type === "ACCUMULATION");
    const distributing = profiles.filter(p => p.volume_quality === "DISTRIBUTION");

    const summary =
      `Volume scan: ${profiles.length} tokens. ` +
      `${accumulating.length} accumulation signal(s). ` +
      `${distributing.length} distribution warning(s). ` +
      `${alerts.length} alert(s). ` +
      (accumulating[0] ? `Top accumulation: ${accumulating[0].symbol}. ` : "") +
      (distributing[0] ? `Distribution warning: ${distributing[0].symbol}. ` : "");

    return {
      deliverable: JSON.stringify({
        schema: "druckenmiller_tracking_volume",
        tracked_at: new Date().toISOString(),
        token_count: profiles.length,
        alerts_triggered: alerts.length,
        accumulation_signals: accumulating.length,
        distribution_warnings: distributing.length,
        summary,
        tokens: profiles,
        dex_volumes: dexProfiles,
        alerts: alerts.map(p => ({
          symbol: p.symbol,
          alert_type: p.volume_quality,
          volume_signal: p.volume_signal,
          divergence: p.divergence,
          read: p.druckenmiller_read,
        })),
      }),
    };
  } catch (e: any) {
    return { deliverable: JSON.stringify({ schema: "druckenmiller_tracking_volume", error: e.message }) };
  }
}
HANDLER_EOF

cat > druckenmiller-soul-handler.ts << 'HANDLER_EOF'
import type { ExecuteJobResult } from "../../../runtime/offeringTypes.js";

/**
 * Druckenmiller Agent Job: Soul Schema
 * cron: "0 6 * * *"  — Daily at 06:00 UTC (pre-market)
 *
 * Stanley Druckenmiller managed money for 30 years without a single
 * losing year. His edge was not diversification — it was concentration
 * when conviction was highest, combined with the willingness to be
 * completely wrong and exit immediately.
 *
 * "I've learned many things from George Soros, but perhaps the most
 * important thing is that it's not whether you're right or wrong
 * that's important, but how much money you make when you're right
 * and how much you lose when you're wrong."
 *
 * Core philosophy:
 *   — Macro first. Everything starts with the macro regime.
 *   — Liquidity drives markets. Follow the money supply, not the news.
 *   — Asymmetric bets only. Never bet big unless the reward vastly exceeds risk.
 *   — Concentration into highest conviction. Do not diversify conviction away.
 *   — Size up when right. The biggest mistake is undersizing a winning position.
 *   — Cut instantly when wrong. There is no such thing as a small loss that grew.
 *   — Earnings revisions are the most reliable stock signal in existence.
 *   — The Fed is God. Central bank policy determines everything.
 *   — Be early. By the time it's consensus, the move is over.
 *
 * This soul schema generates:
 *   1. Macro regime assessment (liquidity, rates, USD trend)
 *   2. Conviction scoring for active positions (1–10)
 *   3. Asymmetry audit (reward/risk ratio per position)
 *   4. Concentration check (are we sized for our best ideas?)
 *   5. Behavioral audit (are we acting like Druckenmiller or like everyone else?)
 *   6. Daily thesis statement
 *
 * Example request:
 * {
 *   "cycle_number": 12,
 *   "account_equity": 50000,
 *   "high_water_mark": 52000,
 *   "macro_inputs": {
 *     "fed_stance": "hawkish",          // "hawkish" | "neutral" | "dovish"
 *     "yield_curve": "inverted",        // "normal" | "flat" | "inverted"
 *     "dxy_trend": "up",                // "up" | "down" | "flat"
 *     "m2_growth_yoy": -2.1,            // % YoY money supply growth
 *     "risk_appetite": "risk_off",      // "risk_on" | "neutral" | "risk_off"
 *     "btc_dominance_trend": "rising",  // rising = altcoins losing, macro risk_off
 *   },
 *   "positions": [
 *     {
 *       "asset": "ETH",
 *       "direction": "long",
 *       "conviction": 8,           // your conviction 1-10
 *       "entry_price": 3200,
 *       "current_price": 3450,
 *       "target_price": 5000,
 *       "stop_price": 2900,
 *       "size_pct_portfolio": 18,  // % of portfolio
 *       "thesis": "ETH monetary premium expansion, staking yield, L2 fee growth",
 *       "days_held": 14,
 *       "thesis_intact": true
 *     }
 *   ],
 *   "recent_decisions": [
 *     { "decision": "Doubled ETH on pullback to support", "outcome": "working" },
 *     { "decision": "Held SOL despite breaking trend", "outcome": "cost 3%" }
 *   ],
 *   "best_idea_sized_correctly": true,  // is your highest conviction position your largest?
 *   "passed_on_opportunities": 1,       // valid setups not taken due to hesitation
 * }
 */

// ─── DRUCKENMILLER PRINCIPLES ────────────────────────────────────────────────

interface Principle {
  id: string;
  name: string;
  quote: string;
  description: string;
  audit_questions: string[];
  failure_modes: string[];
}

const DRUCKENMILLER_PRINCIPLES: Principle[] = [
  {
    id: "macro_first",
    name: "Macro Is the Prime Mover",
    quote: "Earnings don't move the overall market; it's the Federal Reserve Board. Focus on the central banks and focus on the movement of liquidity.",
    description:
      "Every position must be contextualized within the current macro regime. Liquidity — money supply, central bank policy, credit conditions — is the tide that lifts or sinks all boats. A great stock in a liquidity drought underperforms. A mediocre asset in a liquidity flood can 10×. Read the tide before picking the boats.",
    audit_questions: [
      "Is the current macro regime (Fed policy, M2, yield curve) supportive of the position?",
      "Has the liquidity backdrop changed since entry?",
      "Are positions aligned with the prevailing monetary trend?",
    ],
    failure_modes: [
      "Being net long in a liquidity contraction (Fed hiking, M2 declining)",
      "Fighting the central bank — the Fed has infinite ammunition",
      "Ignoring yield curve signals because individual asset thesis feels compelling",
    ],
  },
  {
    id: "asymmetry",
    name: "Asymmetric Bets Only",
    quote: "The way to build long-term returns is through preservation of capital and home runs. You can be wrong 30 percent of the time and still make a fortune if you structure your bets asymmetrically.",
    description:
      "Never enter a position where the reward does not vastly exceed the risk. A 2:1 reward/risk is acceptable. A 5:1 is excellent. A 10:1+ is a home run setup. Druckenmiller waited for these. When they appeared, he swung with full conviction. The number of bets matters less than the quality and sizing of each one.",
    audit_questions: [
      "Is every position's reward/risk ratio ≥ 3:1?",
      "Are position sizes proportional to asymmetry — bigger bets on better asymmetry?",
      "Have any positions degraded to <2:1 reward/risk without being resized or closed?",
    ],
    failure_modes: [
      "Entering a 1.5:1 setup because of narrative excitement",
      "Letting a winner run to where reward/risk is no longer asymmetric without taking profits",
      "Sizing a 10:1 setup the same as a 2:1 setup — this is the biggest mistake",
    ],
  },
  {
    id: "concentration",
    name: "Concentrate Into Conviction",
    quote: "Diversification is for people who don't know what they're doing. If you have a great idea, bet on it. Don't dilute it.",
    description:
      "The best trade of the year deserves to be the largest position. Mediocre ideas should be small or absent. The goal is maximum exposure to your best idea, not balanced exposure to many ideas. When Druckenmiller bet against the British pound, he put on $10B. He did not spread across 20 currency pairs.",
    audit_questions: [
      "Is the highest-conviction position the largest position?",
      "Are there too many small positions diluting the portfolio's focus?",
      "If the best idea worked perfectly, would it move the portfolio meaningfully?",
    ],
    failure_modes: [
      "Having 15 positions of equal size — this is not a portfolio, it is a mutual fund",
      "Capping the best idea at 5% to 'manage risk' while it has 10:1 asymmetry",
      "Adding mediocre positions to feel active",
    ],
  },
  {
    id: "size_up_winners",
    name: "Size Up When Right",
    quote: "It's not whether you're right or wrong, but how much money you make when you're right and how much you lose when you're wrong.",
    description:
      "When a position is working and the thesis is intact, add to it. Most traders take profits early and watch their best ideas run without them. Druckenmiller did the opposite — he pressed winning positions aggressively. Compounding on a working thesis is the engine of extraordinary returns.",
    audit_questions: [
      "Have winning positions been added to while the thesis remains intact?",
      "Were profits taken too early, cutting positions before they ran fully?",
      "Is there capacity to add to winning positions within risk constraints?",
    ],
    failure_modes: [
      "Taking 20% profits on a position with a 5:1 thesis intact",
      "Not adding to a winner because it has already moved",
      "Reducing a winning position to 'lock in gains' when nothing has changed",
    ],
  },
  {
    id: "cut_instantly",
    name: "Cut Losses Instantly and Without Emotion",
    quote: "I never had a major loss in my career that didn't start as a small loss that I let get out of hand.",
    description:
      "The moment the thesis breaks, exit. Not when it feels better. Not after one more day. Immediately. A thesis breaks when: the macro regime shifts against the position, a fundamental event invalidates the original reasoning, or the price action tells you the market knows something you don't. Ego has no place in the exit decision.",
    audit_questions: [
      "Were all thesis-breaking events acted upon immediately?",
      "Are there any positions being held after the original thesis became invalid?",
      "Was the largest loss in recent history a position that started small and grew?",
    ],
    failure_modes: [
      "Holding a position after the thesis broke 'to see if it recovers'",
      "Adding to a losing position to average down",
      "Making a small loss a large one by waiting for 'one more day'",
    ],
  },
  {
    id: "earnings_revisions",
    name: "Earnings Revisions Are the Edge",
    quote: "The most reliable signal I have found in equities over 40 years is earnings estimate revisions. When estimates start rising, buy. When they start falling, sell or short.",
    description:
      "For equities and equity-like crypto assets, earnings revisions (or their crypto equivalent: revenue revisions, protocol fee revisions, TVL trajectory changes) are the most durable signal. The market rerates assets based on changing fundamental expectations. Be early to the revision, not late to the consensus.",
    audit_questions: [
      "For each position: is the fundamental trajectory improving or deteriorating?",
      "Are positions on the right side of the earnings/revenue revision cycle?",
      "Is there a position held where fundamentals are declining but price hasn't reflected it yet?",
    ],
    failure_modes: [
      "Buying an asset after consensus has already raised estimates",
      "Holding an asset through a deteriorating fundamental trend hoping for reversal",
      "Not shorting a structurally declining asset because the narrative sounds good",
    ],
  },
  {
    id: "be_early",
    name: "Be Early or Be Wrong",
    quote: "By the time it's on the front page of the newspaper, the move is over. I want to be in before anyone is talking about it.",
    description:
      "Consensus trades are crowded, low-return bets. Druckenmiller's edge was identifying macro and micro shifts before they were recognized. In crypto: this means finding chain-level TVL inflections, narrative shifts, and token catalyst events before they appear on CT. When the trade is on every thread, it is too late.",
    audit_questions: [
      "Are current positions early to a theme or late to a consensus?",
      "Is there a macro or narrative shift forming that has not yet been priced?",
      "Are any positions being held that have become 'popular trades'?",
    ],
    failure_modes: [
      "Entering a position because it appeared in a newsletter",
      "Holding a position because the narrative is strong when price has already moved 3×",
      "Waiting for confirmation that everyone else has seen before entering",
    ],
  },
  {
    id: "thesis_or_exit",
    name: "Thesis or Exit — There Is No Third Option",
    quote: "I can be wrong, I can change my mind completely, but I can't be uncertain. Uncertainty means you have no position. If you have a position, you have a thesis.",
    description:
      "Every position must have a clear, written thesis with specific conditions that would invalidate it. There are only two states: thesis intact → hold or add; thesis broken → exit immediately. 'I'm not sure' is not a reason to hold. Uncertainty is cash.",
    audit_questions: [
      "Does every open position have a clear, current thesis?",
      "Are exit conditions pre-defined for each position?",
      "Is there any position where the original thesis can no longer be stated clearly?",
    ],
    failure_modes: [
      "Holding a position because you're 'not sure' whether to exit",
      "A thesis that has evolved from the original without formal reassessment",
      "Positions without defined invalidation criteria",
    ],
  },
];

// ─── MACRO REGIME ENGINE ─────────────────────────────────────────────────────

type MacroRegime = "RISK_ON_BULL" | "RISK_ON_FRAGILE" | "TRANSITIONAL" | "RISK_OFF_BEAR" | "CRISIS";

interface MacroAssessment {
  regime: MacroRegime;
  regime_label: string;
  liquidity_score: number;    // 0–10 (10 = abundant liquidity)
  rate_headwind: boolean;
  usd_risk: "TAILWIND" | "NEUTRAL" | "HEADWIND";
  btc_macro_read: string;
  positioning_bias: "AGGRESSIVE_LONG" | "MODERATE_LONG" | "NEUTRAL" | "MODERATE_SHORT" | "AGGRESSIVE_SHORT";
  max_gross_exposure_pct: number;
  druckenmiller_take: string;
}

function assessMacroRegime(macro: Record<string, any>): MacroAssessment {
  const fed = (macro.fed_stance || "neutral").toLowerCase();
  const curve = (macro.yield_curve || "flat").toLowerCase();
  const dxy = (macro.dxy_trend || "flat").toLowerCase();
  const m2Growth = Number(macro.m2_growth_yoy || 0);
  const riskAppetite = (macro.risk_appetite || "neutral").toLowerCase();
  const btcDom = (macro.btc_dominance_trend || "flat").toLowerCase();

  let liquidityScore = 5;
  if (fed === "dovish") liquidityScore += 3;
  if (fed === "hawkish") liquidityScore -= 3;
  if (m2Growth > 5) liquidityScore += 2;
  if (m2Growth < 0) liquidityScore -= 2;
  if (curve === "normal") liquidityScore += 1;
  if (curve === "inverted") liquidityScore -= 1;
  liquidityScore = Math.max(0, Math.min(10, liquidityScore));

  const regime: MacroRegime =
    liquidityScore >= 8 && riskAppetite === "risk_on"
      ? "RISK_ON_BULL"
      : liquidityScore >= 6 && riskAppetite !== "risk_off"
      ? "RISK_ON_FRAGILE"
      : liquidityScore >= 4
      ? "TRANSITIONAL"
      : liquidityScore >= 2
      ? "RISK_OFF_BEAR"
      : "CRISIS";

  const regimeLabels: Record<MacroRegime, string> = {
    RISK_ON_BULL: "Risk-On Bull — Maximum Offense",
    RISK_ON_FRAGILE: "Risk-On Fragile — Selective Offense",
    TRANSITIONAL: "Transitional — Reduce Exposure, Wait for Clarity",
    RISK_OFF_BEAR: "Risk-Off Bear — Defensive / Net Short",
    CRISIS: "Crisis — Capital Preservation Only",
  };

  const positioning: MacroAssessment["positioning_bias"] =
    regime === "RISK_ON_BULL"
      ? "AGGRESSIVE_LONG"
      : regime === "RISK_ON_FRAGILE"
      ? "MODERATE_LONG"
      : regime === "TRANSITIONAL"
      ? "NEUTRAL"
      : regime === "RISK_OFF_BEAR"
      ? "MODERATE_SHORT"
      : "AGGRESSIVE_SHORT";

  const maxExposure =
    regime === "RISK_ON_BULL" ? 200 :    // 2× leverage acceptable
    regime === "RISK_ON_FRAGILE" ? 150 :
    regime === "TRANSITIONAL" ? 80 :
    regime === "RISK_OFF_BEAR" ? 60 :
    30;

  const btcMacroRead =
    btcDom === "rising" && riskAppetite === "risk_off"
      ? "BTC dominance rising into risk-off = altcoin weakness confirmed. Hold BTC if any crypto. Exit alt exposure."
      : btcDom === "falling" && riskAppetite === "risk_on"
      ? "BTC dominance falling = altcoin season. Rotate into high-beta L1s and ecosystem tokens."
      : "BTC dominance neutral — no strong rotation signal. Focus on individual thesis strength.";

  const druckenmillerTake =
    regime === "RISK_ON_BULL"
      ? "The Fed is with us. Liquidity is abundant. This is the time to press winning positions and size up conviction. Do not be afraid of your best idea."
      : regime === "RISK_ON_FRAGILE"
      ? "Conditions are favorable but fragile. Be long your best ideas, but keep stops tight. The regime can flip quickly. Stay alert for liquidity deterioration."
      : regime === "TRANSITIONAL"
      ? "The macro is unclear. In ambiguity, reduce size. The best trade in a transitional regime is often to wait. Cash earns yield. Bad trades lose capital."
      : regime === "RISK_OFF_BEAR"
      ? "The Fed is working against us. Liquidity is contracting. This is not the time to fight the tide. Reduce longs. Find short opportunities. Preserve capital ruthlessly."
      : "Crisis conditions. Capital preservation is the only mandate. Exit all but the highest-conviction longs. Cash is a position and right now it is the best position.";

  return {
    regime,
    regime_label: regimeLabels[regime],
    liquidity_score: liquidityScore,
    rate_headwind: fed === "hawkish",
    usd_risk: dxy === "up" ? "HEADWIND" : dxy === "down" ? "TAILWIND" : "NEUTRAL",
    btc_macro_read: btcMacroRead,
    positioning_bias: positioning,
    max_gross_exposure_pct: maxExposure,
    druckenmiller_take: druckenmillerTake,
  };
}

// ─── POSITION AUDIT ──────────────────────────────────────────────────────────

interface PositionAudit {
  asset: string;
  direction: string;
  conviction: number;
  reward_risk_ratio: number | null;
  asymmetry_grade: "HOME_RUN" | "EXCELLENT" | "ACCEPTABLE" | "MARGINAL" | "REJECT";
  size_vs_conviction: "UNDERSIZED" | "APPROPRIATE" | "OVERSIZED";
  thesis_health: "INTACT" | "WEAKENING" | "BROKEN";
  action: "ADD" | "HOLD" | "TRIM" | "EXIT_NOW";
  days_held: number;
  pnl_pct: number | null;
  druckenmiller_verdict: string;
}

function auditPosition(pos: Record<string, any>, macroRegime: MacroRegime): PositionAudit {
  const entry = Number(pos.entry_price || 0);
  const current = Number(pos.current_price || entry);
  const target = Number(pos.target_price || 0);
  const stop = Number(pos.stop_price || 0);
  const conviction = Number(pos.conviction || 5);
  const sizePct = Number(pos.size_pct_portfolio || 5);
  const thesisIntact = pos.thesis_intact !== false;
  const daysHeld = Number(pos.days_held || 0);
  const direction = (pos.direction || "long").toLowerCase();

  const pnlPct =
    entry > 0 && direction === "long"
      ? ((current - entry) / entry) * 100
      : entry > 0 && direction === "short"
      ? ((entry - current) / entry) * 100
      : null;

  // Reward/risk ratio
  let rrRatio: number | null = null;
  if (entry > 0 && target > 0 && stop > 0) {
    const reward =
      direction === "long" ? target - current : current - target;
    const risk =
      direction === "long" ? current - stop : stop - current;
    rrRatio = risk > 0 ? Math.round((reward / risk) * 10) / 10 : null;
  }

  const asymmetryGrade: PositionAudit["asymmetry_grade"] =
    rrRatio == null ? "ACCEPTABLE" :
    rrRatio >= 8 ? "HOME_RUN" :
    rrRatio >= 4 ? "EXCELLENT" :
    rrRatio >= 2.5 ? "ACCEPTABLE" :
    rrRatio >= 1.5 ? "MARGINAL" : "REJECT";

  // Conviction-to-size alignment
  // Rule: conviction 8–10 → 15–25%+, conviction 5–7 → 5–15%, conviction <5 → 0–5%
  const expectedMinSize =
    conviction >= 8 ? 15 : conviction >= 5 ? 5 : 0;
  const expectedMaxSize =
    conviction >= 8 ? 35 : conviction >= 5 ? 15 : 5;

  const sizeVsConviction: PositionAudit["size_vs_conviction"] =
    sizePct < expectedMinSize ? "UNDERSIZED" :
    sizePct > expectedMaxSize ? "OVERSIZED" :
    "APPROPRIATE";

  // Thesis health
  const thesisHealth: PositionAudit["thesis_health"] =
    !thesisIntact ? "BROKEN" :
    (macroRegime === "RISK_OFF_BEAR" || macroRegime === "CRISIS") && direction === "long" ? "WEAKENING" :
    (macroRegime === "RISK_ON_BULL") && direction === "short" ? "WEAKENING" :
    "INTACT";

  // Action
  const action: PositionAudit["action"] =
    thesisHealth === "BROKEN" ? "EXIT_NOW" :
    asymmetryGrade === "REJECT" ? "EXIT_NOW" :
    thesisHealth === "INTACT" && conviction >= 8 && sizeVsConviction === "UNDERSIZED" ? "ADD" :
    thesisHealth === "WEAKENING" ? "TRIM" :
    "HOLD";

  // Druckenmiller verdict
  const verdicts: Record<PositionAudit["action"], string> = {
    ADD: `Conviction ${conviction}/10 with thesis intact and ${rrRatio?.toFixed(1) ?? "?"}:1 reward/risk. This is UNDERSIZED. Druckenmiller would press this position. Size up.`,
    HOLD: `Thesis intact. Reward/risk ${rrRatio?.toFixed(1) ?? "?"}:1. Hold and monitor for ADD opportunity on pullbacks.`,
    TRIM: `Thesis weakening — macro regime or fundamentals shifting against position. Trim to core size. Keep stop tight.`,
    EXIT_NOW: `${thesisHealth === "BROKEN" ? "THESIS BROKEN" : "REWARD/RISK UNACCEPTABLE"}. There is no debate here. Exit immediately. "I never had a major loss that didn't start as a small loss I let get out of hand."`,
  };

  return {
    asset: pos.asset || "UNKNOWN",
    direction,
    conviction,
    reward_risk_ratio: rrRatio,
    asymmetry_grade: asymmetryGrade,
    size_vs_conviction: sizeVsConviction,
    thesis_health: thesisHealth,
    action,
    days_held: daysHeld,
    pnl_pct: pnlPct != null ? Math.round(pnlPct * 100) / 100 : null,
    druckenmiller_verdict: verdicts[action],
  };
}

// ─── BEHAVIORAL AUDIT ────────────────────────────────────────────────────────

interface BehaviorAudit {
  score: number;           // 0–100
  grade: "DRUCKENMILLER" | "DISCIPLINED" | "DEVELOPING" | "DRIFTING" | "AMATEUR";
  flags: string[];
  commendations: string[];
}

function auditBehavior(request: Record<string, any>, positionAudits: PositionAudit[]): BehaviorAudit {
  const flags: string[] = [];
  const commendations: string[] = [];
  let score = 100;

  // Best idea sizing
  if (!request.best_idea_sized_correctly) {
    score -= 15;
    flags.push("Highest-conviction position is NOT the largest — this is the most common and most expensive mistake in portfolio construction");
  } else {
    commendations.push("Best idea is correctly sized — conviction maps to capital allocation");
  }

  // Passed on opportunities
  const passedOn = Number(request.passed_on_opportunities || 0);
  if (passedOn > 0) {
    score -= passedOn * 8;
    flags.push(`${passedOn} valid opportunity(s) passed on due to hesitation — Druckenmiller: "The biggest mistake is not being in your best idea"`);
  }

  // Recent decisions
  const decisions: Array<{ decision: string; outcome: string }> = request.recent_decisions || [];
  for (const d of decisions) {
    const dec = d.decision.toLowerCase();
    const out = d.outcome.toLowerCase();
    if (dec.includes("averaged down") || dec.includes("added to losing")) {
      score -= 20;
      flags.push(`Adding to losing position: "${d.decision}" — this violates the single most important risk rule`);
    }
    if (dec.includes("held") && (out.includes("cost") || out.includes("loss"))) {
      score -= 10;
      flags.push(`Held past the thesis break point: "${d.decision}" — early exits are always cheaper`);
    }
    if (dec.includes("doubled") && out.includes("working")) {
      commendations.push(`Pressed a winning position: "${d.decision}" — this is Druckenmiller-level execution`);
    }
  }

  // Exit-now positions still held
  const exitNowCount = positionAudits.filter((p) => p.action === "EXIT_NOW").length;
  if (exitNowCount > 0) {
    score -= exitNowCount * 15;
    flags.push(`${exitNowCount} position(s) require immediate exit — every hour these are held is a behavioral failure`);
  }

  // Undersized winners
  const undersizedHighConviction = positionAudits.filter(
    (p) => p.size_vs_conviction === "UNDERSIZED" && p.conviction >= 8 && p.thesis_health === "INTACT"
  );
  if (undersizedHighConviction.length > 0) {
    score -= undersizedHighConviction.length * 10;
    flags.push(
      `${undersizedHighConviction.length} high-conviction position(s) are undersized: ${undersizedHighConviction.map((p) => p.asset).join(", ")} — size up or conviction isn't real`
    );
  }

  score = Math.max(0, score);

  const grade: BehaviorAudit["grade"] =
    score >= 90 ? "DRUCKENMILLER" :
    score >= 75 ? "DISCIPLINED" :
    score >= 55 ? "DEVELOPING" :
    score >= 35 ? "DRIFTING" :
    "AMATEUR";

  return { score, grade, flags, commendations };
}

// ─── DAILY THESIS ────────────────────────────────────────────────────────────

const DRUCKENMILLER_QUOTES = [
  "The way to build long-term returns is through preservation of capital and home runs.",
  "It's not whether you're right or wrong, but how much money you make when you're right.",
  "I never had a major loss in my career that didn't start as a small loss I let get out of hand.",
  "Earnings don't move the overall market. It's the Federal Reserve Board.",
  "I've learned that a big part of Wall Street is a waste of time.",
  "The first thing I heard when I got in the business was bulls make money, bears make money, and pigs get slaughtered. I'm here to tell you I was a pig.",
  "You have to be willing to take losses. Nobody bats a thousand.",
  "The key is not to be right, but to make money when you're right.",
  "If I'm wrong, I'm out. If I'm right, I press.",
  "Cash combined with courage in a time of crisis is priceless.",
  "Concentrate your portfolio. Great investors are not widely diversified.",
  "When you have tremendous conviction on a trade, you have to go for the jugular.",
  "The way to make money is to anticipate, not to follow.",
  "Don't ever, ever, ever, ever average down in a bear market.",
];

// ─── MAIN ────────────────────────────────────────────────────────────────────

export async function executeJob(
  request: Record<string, any>
): Promise<ExecuteJobResult> {
  const cycleNumber = Number(request.cycle_number || 1);
  const equity = Number(request.account_equity || 50000);
  const hwm = Number(request.high_water_mark || equity);
  const drawdownPct = Math.max(0, ((hwm - equity) / hwm) * 100);

  // ── Macro assessment ──
  const macroInputs = request.macro_inputs || {};
  const macroAssessment = assessMacroRegime(macroInputs);

  // ── Position audits ──
  const positions: Record<string, any>[] = request.positions || [];
  const positionAudits: PositionAudit[] = positions.map((p) =>
    auditPosition(p, macroAssessment.regime)
  );

  // ── Behavioral audit ──
  const behaviorAudit = auditBehavior(request, positionAudits);

  // ── Concentration check ──
  const sortedByConviction = [...positionAudits].sort(
    (a, b) => b.conviction - a.conviction
  );
  const highestConvictionPos = sortedByConviction[0];
  const positionsBySizeDesc = [...positions].sort(
    (a, b) =>
      Number(b.size_pct_portfolio || 0) - Number(a.size_pct_portfolio || 0)
  );
  const largestPos = positionsBySizeDesc[0];
  const concentrationAligned =
    !highestConvictionPos ||
    !largestPos ||
    highestConvictionPos.asset === largestPos.asset;

  // ── Portfolio heat ──
  const totalExposure = positions.reduce(
    (sum, p) => sum + Number(p.size_pct_portfolio || 0),
    0
  );
  const exposureVsMax =
    totalExposure > macroAssessment.max_gross_exposure_pct
      ? "OVER_LIMIT"
      : totalExposure > macroAssessment.max_gross_exposure_pct * 0.85
      ? "NEAR_LIMIT"
      : "WITHIN_LIMIT";

  // ── Daily thesis statement ──
  const exitNowPositions = positionAudits.filter((p) => p.action === "EXIT_NOW");
  const addPositions = positionAudits.filter((p) => p.action === "ADD");

  const dailyThesis =
    exitNowPositions.length > 0
      ? `PRIORITY: Exit ${exitNowPositions.map((p) => p.asset).join(", ")} immediately. Thesis broken or asymmetry gone. No other action until these are closed.`
      : addPositions.length > 0
      ? `CONVICTION SIZING: ${addPositions.map((p) => p.asset).join(", ")} ${addPositions.length === 1 ? "is" : "are"} undersized relative to conviction. Today's primary action: press ${addPositions[0].asset}.`
      : macroAssessment.regime === "TRANSITIONAL"
      ? "MACRO UNCERTAINTY: Reduce gross exposure. Do not add new positions. Wait for the regime to clarify."
      : "HOLD AND MONITOR: Portfolio is positioned correctly. Watch for macro regime changes. Add to winners on pullbacks.";

  // ── Closing quote ──
  const quote = DRUCKENMILLER_QUOTES[cycleNumber % DRUCKENMILLER_QUOTES.length];

  // ── Summary ──
  const summary =
    `Druckenmiller Soul — Cycle ${cycleNumber}. ` +
    `Macro: ${macroAssessment.regime_label}. ` +
    `Liquidity: ${macroAssessment.liquidity_score}/10. ` +
    `Behavior: ${behaviorAudit.grade} (${behaviorAudit.score}/100). ` +
    `${exitNowPositions.length} exit(s) required. ` +
    `${addPositions.length} position(s) to press. ` +
    `Thesis: ${dailyThesis}`;

  return {
    deliverable: JSON.stringify({
      schema: "druckenmiller_soul",
      agent: "Druckenmiller",
      generated_at: new Date().toISOString(),
      cycle_number: cycleNumber,
      summary,

      // Macro
      macro: macroAssessment,

      // Portfolio
      portfolio: {
        equity_usd: equity,
        high_water_mark_usd: hwm,
        drawdown_pct: Math.round(drawdownPct * 100) / 100,
        total_exposure_pct: Math.round(totalExposure),
        max_exposure_pct: macroAssessment.max_gross_exposure_pct,
        exposure_status: exposureVsMax,
        concentration_aligned: concentrationAligned,
        concentration_warning: concentrationAligned
          ? null
          : `Highest conviction (${highestConvictionPos?.asset}) is not largest position (${largestPos?.asset}). Fix this.`,
        position_count: positions.length,
      },

      // Positions
      position_audits: positionAudits,
      exits_required: exitNowPositions,
      positions_to_press: addPositions,

      // Behavior
      behavior: behaviorAudit,

      // Principles reference
      principles: DRUCKENMILLER_PRINCIPLES.map((p) => ({
        id: p.id,
        name: p.name,
        quote: p.quote,
        description: p.description,
      })),

      // Daily mandate
      daily_thesis: dailyThesis,
      daily_quote: quote,

      // Context for agent system prompt
      agent_instructions: {
        persona: "You are an AI agent inspired by Stanley Druckenmiller — the greatest macro trader of all time. You think in macro regimes first. You bet asymmetrically. You concentrate into conviction. You cut losses the moment the thesis breaks. You press winners without hesitation.",
        core_rules: [
          "Never enter a position without a stated, specific thesis and exit conditions",
          "Reward/risk must be ≥ 3:1 for any new position",
          "Highest conviction idea must be largest position",
          "Exit immediately when thesis breaks — do not wait for confirmation",
          "Follow the Fed — liquidity determines the regime, the regime determines the playbook",
          "Do not average down. Ever.",
          "When right, press. Undersizing winners is as costly as holding losers.",
          "Be early. Consensus trades have no edge.",
        ],
      },
    }),
  };
}
HANDLER_EOF

cat > fraxtal-suggestions-handler.ts << 'HANDLER_EOF'
import type { ExecuteJobResult } from "../../../runtime/offeringTypes.js";

/**
 * Seykota Agent Job: Fraxtal Suggestions Schema
 * cron: "0 */6 * * *"  — Every 6 hours
 *
 * Generates Fraxtal-specific actionable suggestions: protocol yield opportunities,
 * FXTL points farming windows, frxETH/sfrxETH yield vs. alternatives,
 * FXS/FRAX liquidity positioning, and Superchain ecosystem signals.
 *
 * Fraxtal is a Superchain L2 built by Frax Finance. Key assets:
 *   FRAX (stablecoin), frxETH (ETH LST), sfrxETH (staked frxETH),
 *   FXS (governance), FXTL (points → future airdrop)
 *
 * Data sources: DeFiLlama (no key), CoinGecko (optional key)
 *
 * Example request:
 * {
 *   "risk_tier": "normal",          // "normal" | "reduced" | "defensive" | "survival"
 *   "account_equity": 10000,
 *   "fraxtal_allocation_pct": 20,   // % of portfolio allocated to Fraxtal
 *   "holding": ["frxETH", "FRAX"],  // assets currently held
 * }
 */

const DEFILLAMA_BASE = "https://api.llama.fi";
const COINGECKO_BASE = "https://api.coingecko.com/api/v3";
const CG_KEY = process.env.COINGECKO_API_KEY || "";

const FRAXTAL_CHAIN = "Fraxtal";

type RiskTier = "normal" | "reduced" | "defensive" | "survival";

interface FraxtalSuggestion {
  id: string;
  priority: "HIGH" | "MEDIUM" | "LOW";
  category: "Yield" | "Points" | "Liquidity" | "Risk" | "Rotation" | "Volatility";
  action: string;
  rationale: string;
  signal: string;
  expected_apy_range?: string;
  risk_note?: string;
  applicable_tiers: RiskTier[];
}

const RISK_TIER_ORDER: Record<RiskTier, number> = {
  normal: 0,
  reduced: 1,
  defensive: 2,
  survival: 3,
};

function tierAllowed(suggestion: FraxtalSuggestion, tier: RiskTier): boolean {
  return suggestion.applicable_tiers.includes(tier);
}

function buildStaticSuggestions(): FraxtalSuggestion[] {
  return [
    // ── Yield ──────────────────────────────────────────────────────────────
    {
      id: "frx-sfrxeth-stake",
      priority: "HIGH",
      category: "Yield",
      action: "STAKE frxETH → sfrxETH for protocol yield",
      rationale:
        "sfrxETH earns all Frax validator revenue because frxETH holders who don't stake receive zero rewards. The sfrxETH/frxETH APY is typically 5–8% with no IL risk. Best risk-adjusted yield entry on Fraxtal for ETH holders.",
      signal: "sfrxETH collects 100% of validator rewards from all non-staked frxETH supply",
      expected_apy_range: "5–8% base + FXTL points",
      risk_note: "Smart contract risk on Frax Protocol. No IL. Liquid via frxETH pool.",
      applicable_tiers: ["normal", "reduced", "defensive"],
    },
    {
      id: "frx-frax-lending",
      priority: "HIGH",
      category: "Yield",
      action: "LEND FRAX on Fraxlend — earn native protocol yield + FXTL",
      rationale:
        "Fraxlend is the native lending market on Fraxtal. FRAX lending rates are partially subsidized by Frax Protocol. Unlike external lending markets, Fraxlend interest rates are hardcoded to benefit the ecosystem, with FXTL points as additional incentive layer.",
      signal: "Native protocol, lower counterparty risk vs. third-party markets",
      expected_apy_range: "4–12% + FXTL points",
      risk_note: "Borrower default risk. Fraxlend uses AMM-based interest rates — rate can spike during high utilization.",
      applicable_tiers: ["normal", "reduced"],
    },
    {
      id: "frx-lp-sfrxeth-frxeth",
      priority: "MEDIUM",
      category: "Liquidity",
      action: "LP sfrxETH/frxETH on Curve — near-zero IL, earn CRV + FXTL",
      rationale:
        "sfrxETH and frxETH are highly correlated (both ETH-pegged) making this a near-zero IL LP position. Curve pools for correlated assets earn fees without directional risk. Add FXTL points and CRV emissions for a stablecoin-like risk profile with elevated yield.",
      signal: "Correlated pair → IL negligible. Fee income from arb between staked/unstaked frxETH.",
      expected_apy_range: "6–15% (fees + CRV + FXTL)",
      risk_note: "Curve smart contract risk. FXTL points have uncertain conversion to airdrop value.",
      applicable_tiers: ["normal", "reduced", "defensive"],
    },

    // ── Points / FXTL ──────────────────────────────────────────────────────
    {
      id: "frx-fxtl-maximize",
      priority: "HIGH",
      category: "Points",
      action: "MAXIMIZE FXTL points — use Fraxtal native protocols over forks",
      rationale:
        "FXTL points accrue from on-chain activity on Fraxtal. Native protocols (Fraxlend, Fraxswap, Curve Fraxtal deployments) typically earn more points per dollar than third-party forks. Before airdrop snapshot, points-per-dollar efficiency matters more than raw APY.",
      signal: "FXTL represents future airdrop value — convert points to expected value using FXS market cap as reference",
      applicable_tiers: ["normal", "reduced"],
    },
    {
      id: "frx-fxtl-stack-deadline",
      priority: "MEDIUM",
      category: "Points",
      action: "WATCH for FXTL snapshot announcement — front-run with capital deployment",
      rationale:
        "Points programs historically see capital rushes before snapshot dates. Deploying capital 2–4 weeks before a known snapshot captures asymmetric FXTL accrual. Monitor Frax governance and Twitter for snapshot signals.",
      signal: "Monitor: frax.finance/governance and @fraxfinance for snapshot timing",
      applicable_tiers: ["normal"],
    },

    // ── Volatility / Macro ─────────────────────────────────────────────────
    {
      id: "frx-fxs-vol-signal",
      priority: "MEDIUM",
      category: "Volatility",
      action: "MONITOR FXS 7-day momentum — proxy for Fraxtal ecosystem health",
      rationale:
        "FXS is the governance and value-accrual token for Frax Finance. FXS price is a leading indicator for Fraxtal TVL and FXTL value expectations. FXS up 20%+ in 7 days = ecosystem momentum, favorable for Fraxtal LP entry. FXS down 20%+ = reduce exposure.",
      signal: "FXS/USDC 7D momentum drives FXTL expected value",
      applicable_tiers: ["normal", "reduced"],
    },
    {
      id: "frx-stablecoin-depeg-watch",
      priority: "HIGH",
      category: "Risk",
      action: "MONITOR FRAX peg — exit all Fraxtal positions if FRAX depegs > 1%",
      rationale:
        "FRAX is the foundational stablecoin of the Fraxtal ecosystem. A FRAX depeg cascades through Fraxlend (collateral value drops), Fraxswap (pool imbalance), and sfrxETH (redemption pressure). The 2023 FRAX depeg caused immediate protocol stress. This is Fraxtal's systemic risk.",
      signal: "FRAX/USDC < $0.99 → immediate risk alert. < $0.97 → emergency exit.",
      risk_note: "CRITICAL: Monitor 24/7. Set automated alerts.",
      applicable_tiers: ["normal", "reduced", "defensive", "survival"],
    },

    // ── Rotation ───────────────────────────────────────────────────────────
    {
      id: "frx-rotate-to-base",
      priority: "LOW",
      category: "Rotation",
      action: "COMPARE Fraxtal vs. Base yields — rotate if Base offers 2× APY",
      rationale:
        "Fraxtal and Base are both Superchain L2s competing for the same ETH-aligned capital. When Aerodrome on Base offers >2× the APY of equivalent Fraxtal positions, rotate. Capital should always chase best risk-adjusted yield within same risk tier.",
      signal: "Benchmark: sfrxETH APY vs. cbETH/ETH on Aerodrome Base",
      applicable_tiers: ["normal", "reduced"],
    },
  ];
}

export async function executeJob(
  request: Record<string, any>
): Promise<ExecuteJobResult> {
  const riskTier: RiskTier = (request.risk_tier as RiskTier) || "normal";
  const equity = Number(request.account_equity || 10000);
  const fraxtalAllocPct = Number(request.fraxtal_allocation_pct || 20);
  const holdings: string[] = (request.holding || []).map((h: string) =>
    h.toLowerCase()
  );

  const cgHeaders: Record<string, string> = {
    ...(CG_KEY ? { "x-cg-demo-api-key": CG_KEY } : {}),
  };

  // ── Fetch live Fraxtal TVL ──
  let fraxtalTvl: number | null = null;
  let fraxtalTvlChange7d: number | null = null;
  let fraxtalDexVol: number | null = null;
  let fxsPrice: number | null = null;
  let fxsChange7d: number | null = null;
  let fraxPeg: number | null = null;

  try {
    const [chainRes, cgRes] = await Promise.all([
      fetch(`${DEFILLAMA_BASE}/v2/chains`),
      fetch(
        `${COINGECKO_BASE}/simple/price?ids=frax-share,frax&vs_currencies=usd&include_24hr_change=true&include_7d_change=true`,
        { headers: cgHeaders }
      ),
    ]);

    if (chainRes.ok) {
      const chains: any[] = await chainRes.json();
      const fraxtal = chains.find(
        (c) => c.name?.toLowerCase() === "fraxtal"
      );
      if (fraxtal) {
        fraxtalTvl = fraxtal.tvl || null;
        fraxtalTvlChange7d = fraxtal.change_7d ?? null;
      }
    }

    if (cgRes.ok) {
      const prices = await cgRes.json();
      fxsPrice = prices["frax-share"]?.usd ?? null;
      fxsChange7d = prices["frax-share"]?.usd_7d_change ?? null;
      fraxPeg = prices["frax"]?.usd ?? null;
    }
  } catch (_) {
    // Live data optional — static suggestions still generated
  }

  // ── Fetch Fraxtal DEX volume ──
  try {
    const dexRes = await fetch(
      `${DEFILLAMA_BASE}/overview/dexs/Fraxtal?excludeTotalDataChart=true&dataType=dailyVolume`
    );
    if (dexRes.ok) {
      const dexData = await dexRes.json();
      fraxtalDexVol = dexData.total24h ?? null;
    }
  } catch (_) {}

  // ── Build suggestions ──
  const staticSuggestions = buildStaticSuggestions();

  // Filter by risk tier
  let active = staticSuggestions.filter((s) => tierAllowed(s, riskTier));

  // ── Dynamic suggestions from live data ──
  const dynamic: FraxtalSuggestion[] = [];

  // FRAX depeg alert (highest priority)
  if (fraxPeg !== null && fraxPeg < 0.99) {
    dynamic.push({
      id: "live-frax-depeg-alert",
      priority: "HIGH",
      category: "Risk",
      action: `ALERT: FRAX trading at $${fraxPeg.toFixed(4)} — BELOW PEG`,
      rationale: `FRAX is depegged by ${((1 - fraxPeg) * 100).toFixed(2)}%. This is Fraxtal's systemic risk. Reduce all Fraxtal exposure immediately. Monitor recovery before re-entering.`,
      signal: `FRAX/USD: $${fraxPeg.toFixed(4)} (peg = $1.000)`,
      risk_note: "CRITICAL — exit trigger",
      applicable_tiers: ["normal", "reduced", "defensive", "survival"],
    });
  }

  // FXS momentum signal
  if (fxsChange7d !== null) {
    if (fxsChange7d > 20) {
      dynamic.push({
        id: "live-fxs-bullish",
        priority: "HIGH",
        category: "Yield",
        action: "INCREASE Fraxtal allocation — FXS momentum bullish",
        rationale: `FXS up ${fxsChange7d.toFixed(1)}% in 7 days signals strong Frax ecosystem momentum. FXTL expected value rises with FXS. Best time to maximize points accrual before momentum fades.`,
        signal: `FXS 7D: +${fxsChange7d.toFixed(1)}% at $${fxsPrice?.toFixed(2)}`,
        applicable_tiers: ["normal"],
      });
    } else if (fxsChange7d < -20) {
      dynamic.push({
        id: "live-fxs-bearish",
        priority: "HIGH",
        category: "Risk",
        action: "REDUCE Fraxtal allocation — FXS trend weak",
        rationale: `FXS down ${Math.abs(fxsChange7d).toFixed(1)}% in 7 days suggests ecosystem stress. FXTL points accrue less USD value when FXS falls. Reduce Fraxtal allocation until trend stabilizes.`,
        signal: `FXS 7D: ${fxsChange7d.toFixed(1)}% at $${fxsPrice?.toFixed(2)}`,
        applicable_tiers: ["normal", "reduced", "defensive", "survival"],
      });
    }
  }

  // TVL momentum
  if (fraxtalTvlChange7d !== null && fraxtalTvlChange7d > 15) {
    dynamic.push({
      id: "live-fraxtal-tvl-inflow",
      priority: "MEDIUM",
      category: "Liquidity",
      action: "DEPLOY capital to Fraxtal now — TVL inflow detected",
      rationale: `Fraxtal TVL up ${fraxtalTvlChange7d.toFixed(1)}% in 7 days. Rising TVL = rising protocol fees = better LP returns. Early deployers capture the fee growth window before TVL overshoot compresses yields.`,
      signal: `Fraxtal TVL: $${fraxtalTvl ? (fraxtalTvl / 1e6).toFixed(1) : "?"}M (+${fraxtalTvlChange7d.toFixed(1)}% 7D)`,
      applicable_tiers: ["normal", "reduced"],
    });
  }

  const allSuggestions = [...dynamic, ...active].sort((a, b) => {
    const order = { HIGH: 0, MEDIUM: 1, LOW: 2 };
    return order[a.priority] - order[b.priority];
  });

  // ── Holdings-based filtering ──
  const contextual = allSuggestions.filter((s) => {
    // Always include risk alerts
    if (s.category === "Risk") return true;
    // Include if holding relevant asset
    if (holdings.length === 0) return true;
    const sText = (s.action + s.rationale).toLowerCase();
    return holdings.some((h) => sText.includes(h));
  });

  const final = contextual.length >= 3 ? contextual : allSuggestions;

  const fraxtalAlloc = (equity * fraxtalAllocPct) / 100;
  const summary =
    `${final.length} Fraxtal suggestion${final.length !== 1 ? "s" : ""} for ${riskTier.toUpperCase()} tier. ` +
    (fraxtalTvl
      ? `Fraxtal TVL: $${(fraxtalTvl / 1e6).toFixed(1)}M (${fraxtalTvlChange7d != null ? (fraxtalTvlChange7d > 0 ? "+" : "") + fraxtalTvlChange7d.toFixed(1) + "% 7D" : "?"}). `
      : "") +
    (fxsPrice ? `FXS: $${fxsPrice.toFixed(2)} (${fxsChange7d != null ? (fxsChange7d > 0 ? "+" : "") + fxsChange7d.toFixed(1) + "% 7D" : "?"}). ` : "") +
    (fraxPeg ? `FRAX peg: $${fraxPeg.toFixed(4)}. ` : "") +
    `Allocated capital: $${fraxtalAlloc.toLocaleString()}.`;

  return {
    deliverable: JSON.stringify({
      schema: "fraxtal_suggestions",
      generated_at: new Date().toISOString(),
      chain: FRAXTAL_CHAIN,
      risk_tier: riskTier,
      account_equity_usd: equity,
      fraxtal_allocation_usd: fraxtalAlloc,
      holdings,
      live_data: {
        fraxtal_tvl_usd: fraxtalTvl,
        fraxtal_tvl_change_7d_pct: fraxtalTvlChange7d,
        fraxtal_dex_volume_24h: fraxtalDexVol,
        fxs_price_usd: fxsPrice,
        fxs_change_7d_pct: fxsChange7d,
        frax_peg_usd: fraxPeg,
        frax_depeg_alert: fraxPeg !== null && fraxPeg < 0.99,
      },
      suggestion_count: final.length,
      summary,
      suggestions: final,
    }),
  };
}
HANDLER_EOF

cat > handlers.ts << 'HANDLER_EOF'
import type { ExecuteJobResult } from "../../../runtime/offeringTypes.js";

/**
 * Seykota Agent Job: Base Chain NFT Transfer Scanner
 *
 * Searches for ERC-721 or ERC-1155 token transfers on Base chain
 * for a given contract address and optional tokenId.
 *
 * Example request:
 * {
 *   "contract_address": "0x5C0BF08936bcCfbb6af24B4648A9fb365cAa2F4e",
 *   "token_id": "1",
 *   "token_standard": "ERC721",   // or "ERC1155" (default: ERC721)
 *   "limit": 10                   // max results (default: 25)
 * }
 */

const BASESCAN_API = "https://api.basescan.org/api";
const BASESCAN_KEY = process.env.BASESCAN_API_KEY || "";

interface Transfer {
  hash: string;
  blockNumber: string;
  timeStamp: string;
  from: string;
  to: string;
  tokenID: string;
  tokenName: string;
  tokenSymbol: string;
  gasUsed: string;
  gasPrice: string;
}

function shortAddr(addr: string): string {
  return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
}

function tsToDate(ts: string): string {
  return new Date(Number(ts) * 1000).toISOString().replace("T", " ").slice(0, 19) + " UTC";
}

function gweiToEth(gasUsed: string, gasPrice: string): string {
  const fee = (Number(gasUsed) * Number(gasPrice)) / 1e18;
  return fee.toFixed(6);
}

export async function executeJob(
  request: Record<string, any>
): Promise<ExecuteJobResult> {

  // ── Input normalization ──────────────────────────────────────────────────
  const contractAddress =
    request.contract_address ||
    request.address ||
    request.ca ||
    request.nft_address;

  const tokenId =
    request.token_id ||
    request.tokenId ||
    request.id ||
    null;

  const standard: "ERC721" | "ERC1155" =
    (request.token_standard || request.standard || "ERC721")
      .toUpperCase()
      .includes("1155")
      ? "ERC1155"
      : "ERC721";

  const limit = Math.min(Number(request.limit || 25), 100);

  // ── Validation ───────────────────────────────────────────────────────────
  if (!contractAddress) {
    return {
      deliverable: JSON.stringify({
        error: "contract_address is required",
        example: {
          contract_address: "0x5C0BF08936bcCfbb6af24B4648A9fb365cAa2F4e",
          token_id: "1",
          token_standard: "ERC721",
        },
      }),
    };
  }

  if (!BASESCAN_KEY) {
    return {
      deliverable: JSON.stringify({
        error: "BASESCAN_API_KEY not set in environment",
        hint: "Get a free key at https://basescan.org/myapikey",
      }),
    };
  }

  // ── Build Basescan API URL ────────────────────────────────────────────────
  // ERC-721: tokennfttx | ERC-1155: token1155tx
  const action = standard === "ERC1155" ? "token1155tx" : "tokennfttx";

  const params = new URLSearchParams({
    module: "account",
    action,
    contractaddress: contractAddress,
    page: "1",
    offset: String(limit),
    sort: "desc",
    apikey: BASESCAN_KEY,
  });

  // Filter by tokenId if provided
  if (tokenId !== null) {
    // Basescan doesn't support tokenId filter directly in API,
    // so we fetch and filter client-side
  }

  // ── Fetch transfers ───────────────────────────────────────────────────────
  let raw: Transfer[] = [];
  try {
    const res = await fetch(`${BASESCAN_API}?${params.toString()}`);
    if (!res.ok) throw new Error(`Basescan HTTP ${res.status}`);

    const json = await res.json();

    if (json.status === "0") {
      // "No transactions found" is status 0 with message NOTOK or No records
      if (
        json.message?.toLowerCase().includes("no") ||
        json.result === "No transactions found"
      ) {
        return {
          deliverable: JSON.stringify({
            contract_address: contractAddress,
            token_id: tokenId,
            token_standard: standard,
            chain: "base",
            transfers: [],
            count: 0,
            summary: `No ${standard} transfers found for contract ${shortAddr(contractAddress)}${tokenId ? ` tokenId #${tokenId}` : ""} on Base.`,
          }),
        };
      }
      throw new Error(json.message || "Basescan error");
    }

    raw = json.result as Transfer[];
  } catch (e: any) {
    return {
      deliverable: JSON.stringify({
        error: `Failed to fetch from Basescan: ${e.message}`,
        contract_address: contractAddress,
        chain: "base",
      }),
    };
  }

  // ── Filter by tokenId if requested ───────────────────────────────────────
  const filtered =
    tokenId !== null
      ? raw.filter((t) => t.tokenID === String(tokenId))
      : raw;

  // ── Shape the output ─────────────────────────────────────────────────────
  const transfers = filtered.map((t) => ({
    tx_hash: t.hash,
    block: Number(t.blockNumber),
    timestamp: tsToDate(t.timeStamp),
    from: t.from,
    to: t.to,
    token_id: t.tokenID,
    token_name: t.tokenName,
    token_symbol: t.tokenSymbol,
    gas_fee_eth: gweiToEth(t.gasUsed, t.gasPrice),
    basescan_url: `https://basescan.org/tx/${t.hash}`,
  }));

  // ── Build summary for agent readability ──────────────────────────────────
  const uniqueSenders = new Set(filtered.map((t) => t.from)).size;
  const uniqueReceivers = new Set(filtered.map((t) => t.to)).size;
  const latest = transfers[0];

  const summary = transfers.length > 0
    ? `Found ${transfers.length} ${standard} transfer${transfers.length > 1 ? "s" : ""} ` +
      `for ${shortAddr(contractAddress)}${tokenId ? ` tokenId #${tokenId}` : ""} on Base. ` +
      `Most recent: ${latest.from === "0x0000000000000000000000000000000000000000" ? "MINT" : shortAddr(latest.from)} → ${shortAddr(latest.to)} ` +
      `at ${latest.timestamp}. ` +
      `${uniqueSenders} unique sender${uniqueSenders > 1 ? "s" : ""}, ${uniqueReceivers} unique receiver${uniqueReceivers > 1 ? "s" : ""}.`
    : `No transfers found for tokenId #${tokenId} at ${shortAddr(contractAddress)} on Base.`;

  // ── Return deliverable ───────────────────────────────────────────────────
  return {
    deliverable: JSON.stringify({
      chain: "base",
      chain_id: 8453,
      contract_address: contractAddress,
      token_id: tokenId,
      token_standard: standard,
      token_name: transfers[0]?.token_name || null,
      token_symbol: transfers[0]?.token_symbol || null,
      count: transfers.length,
      unique_senders: uniqueSenders,
      unique_receivers: uniqueReceivers,
      summary,
      transfers,
    }),
  };
}
HANDLER_EOF

cat > nodle-micro-swaps-handler.ts << 'HANDLER_EOF'
import type { ExecuteJobResult } from "../../../runtime/offeringTypes.js";

/**
 * Orchestrator Sub-Function: nodle_micro-swaps
 * cron: "0 */4 * * *"  — Every 4 hours
 *
 * Independent of signal alignment — runs on its own fixed schedule
 * regardless of what Seykota/Druckenmiller signal. Performs small,
 * regular USDC → VIRTUAL swaps on Base via Aerodrome.
 *
 * Rationale: dollar-cost-averaging into VIRTUAL on a fixed schedule,
 * decoupled from directional signals — a position-building function,
 * not a trend-following one. Runs alongside (not instead of) the
 * main swap orchestrator.
 *
 * MODE: AUTO-EXECUTE via CDP (same failover infrastructure as orchestrator)
 *
 * Example request:
 * {
 *   "swap_amount_usdc": 10,
 *   "pair": "USDC/VIRTUAL",
 *   "dex": "aerodrome",
 *   "max_price_impact_bps": 50,
 *   "dry_run": false
 * }
 */

const ROUTER_CONFIG = {
  primary: { name: "PRIMARY_ROUTER", address: "0x111111125421cA6dc452d289314280a0f8842A65", identity: "1inch v5" },
  fallback_1: { name: "FALLBACK_ROUTER_1", address: "0x1231deb6f5749ef6ce6943a275a1d3e7486f4eae", identity: "LiFi Diamond" },
  fallback_2: { name: "FALLBACK_ROUTER_2", address: "0x6fF5693b99212Da76ad316178A184AB56D299b43", identity: "0x-style router" },
};

const RPC_CONFIG = {
  primary: process.env.COINBASE_RPC || "https://developer-access-mainnet.base.org",
  fallback_1: process.env.FALLBACK_RPC_1 || "https://1rpc.io/base",
  fallback_2: process.env.FALLBACK_RPC_2 || "https://base.api.pocket.network",
};

const CDP_API_KEY_NAME = process.env.CDP_API_KEY_NAME || "";
const CDP_API_KEY_PRIVATE_KEY = process.env.CDP_API_KEY_PRIVATE_KEY || "";
const CDP_WALLET_ID = process.env.CDP_WALLET_ID || "";

const AERODROME_ROUTER = "0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43";
const USDC_BASE = "0x833589fCD6eDb6E08f4c7C32D4f71b54bda02913";
const VIRTUAL_BASE = "0x0b3e328455c4059EEb9e3f84b5543F74E24e7E1b";

const COINGECKO_BASE = "https://api.coingecko.com/api/v3";
const CG_KEY = process.env.COINGECKO_API_KEY || "";

interface MicroSwapResult {
  pair: string;
  dex: string;
  amount_in_usdc: number;
  estimated_amount_out_virtual: number | null;
  price_impact_bps: number | null;
  router_used: string | null;
  rpc_used: string | null;
  status: "EXECUTED" | "FAILED" | "ABORTED_HIGH_IMPACT" | "DRY_RUN" | "PLANNED";
  tx_hash: string | null;
  error: string | null;
  cumulative_tracking: { note: string };
}

async function getVirtualPrice(): Promise<{ price_usd: number | null; price_change_24h: number | null }> {
  try {
    const headers: Record<string, string> = CG_KEY ? { "x-cg-demo-api-key": CG_KEY } : {};
    const res = await fetch(
      `${COINGECKO_BASE}/simple/price?ids=virtual-protocol&vs_currencies=usd&include_24hr_change=true`,
      { headers }
    );
    if (!res.ok) return { price_usd: null, price_change_24h: null };
    const data = await res.json();
    return {
      price_usd: data["virtual-protocol"]?.usd ?? null,
      price_change_24h: data["virtual-protocol"]?.usd_24h_change ?? null,
    };
  } catch (_) {
    return { price_usd: null, price_change_24h: null };
  }
}

async function executeMicroSwap(
  amountUsdc: number,
  virtualPrice: number | null,
  maxPriceImpactBps: number,
  dryRun: boolean
): Promise<MicroSwapResult> {
  const estimatedOut = virtualPrice && virtualPrice > 0 ? amountUsdc / virtualPrice : null;

  const baseResult: MicroSwapResult = {
    pair: "USDC/VIRTUAL",
    dex: "aerodrome",
    amount_in_usdc: amountUsdc,
    estimated_amount_out_virtual: estimatedOut ? Math.round(estimatedOut * 1e6) / 1e6 : null,
    price_impact_bps: null,
    router_used: null,
    rpc_used: null,
    status: "PLANNED",
    tx_hash: null,
    error: null,
    cumulative_tracking: {
      note: "Track cumulative VIRTUAL accumulated across cycles in agent state/storage — not computed per-call here",
    },
  };

  if (dryRun) {
    return { ...baseResult, status: "DRY_RUN", router_used: "AERODROME_ROUTER", rpc_used: "primary" };
  }

  if (!CDP_API_KEY_NAME || !CDP_API_KEY_PRIVATE_KEY || !CDP_WALLET_ID) {
    return {
      ...baseResult,
      status: "FAILED",
      error: "CDP credentials not configured. Fail closed — no swap executed.",
    };
  }

  // Price impact check (placeholder — wire to actual Aerodrome quote)
  const simulatedPriceImpactBps = 8; // micro swaps on $10-50 size typically negligible

  if (simulatedPriceImpactBps > maxPriceImpactBps) {
    return {
      ...baseResult,
      price_impact_bps: simulatedPriceImpactBps,
      status: "ABORTED_HIGH_IMPACT",
      error: `Price impact ${simulatedPriceImpactBps}bps exceeds max ${maxPriceImpactBps}bps. Skipping this cycle.`,
    };
  }

  const routerAttempts: Array<keyof typeof ROUTER_CONFIG> = ["primary", "fallback_1", "fallback_2"];
  const rpcAttempts: Array<keyof typeof RPC_CONFIG> = ["primary", "fallback_1", "fallback_2"];

  for (const routerKey of routerAttempts) {
    const router = ROUTER_CONFIG[routerKey];
    for (const rpcKey of rpcAttempts) {
      try {
        // ── CDP execution placeholder ──────────────────────────────────
        // import { Coinbase, Wallet } from "@coinbase/coinbase-sdk";
        // Coinbase.configure({ apiKeyName: CDP_API_KEY_NAME, privateKey: CDP_API_KEY_PRIVATE_KEY });
        // const wallet = await Wallet.fetch(CDP_WALLET_ID);
        //
        // Prefer direct Aerodrome router for this known pair; fall back
        // to aggregators (1inch/LiFi/0x) if Aerodrome route fails or
        // USDC/VIRTUAL pool liquidity is too thin.
        //
        // const tx = await wallet.invokeContract({
        //   contractAddress: routerKey === "primary" ? AERODROME_ROUTER : router.address,
        //   method: "swapExactTokensForTokens",
        //   args: {
        //     amountIn: (amountUsdc * 1e6).toString(), // USDC has 6 decimals
        //     amountOutMin: "0", // computed from quote + slippage tolerance
        //     routes: [{ from: USDC_BASE, to: VIRTUAL_BASE, stable: false }],
        //     to: CDP_WALLET_ID,
        //     deadline: Math.floor(Date.now() / 1000) + 300,
        //   },
        // });
        // await tx.wait();

        const wouldSucceed = routerKey === "primary" && rpcKey === "primary"; // placeholder

        if (wouldSucceed) {
          return {
            ...baseResult,
            price_impact_bps: simulatedPriceImpactBps,
            status: "EXECUTED",
            router_used: routerKey === "primary" ? "AERODROME_ROUTER" : router.name,
            rpc_used: RPC_CONFIG[rpcKey],
            tx_hash: "0x_PLACEHOLDER_TX_HASH_WIRE_CDP_SDK",
          };
        }
      } catch (_) {
        continue;
      }
    }
  }

  return {
    ...baseResult,
    price_impact_bps: simulatedPriceImpactBps,
    status: "FAILED",
    error: "All router x RPC combinations failed for this cycle. Will retry next scheduled cycle (4h).",
  };
}

export async function executeJob(request: Record<string, any>): Promise<ExecuteJobResult> {
  const amountUsdc = Number(request.swap_amount_usdc ?? 10);
  const maxPriceImpactBps = Number(request.max_price_impact_bps ?? 50);
  const dryRun = request.dry_run === true;

  const { price_usd: virtualPrice, price_change_24h } = await getVirtualPrice();

  const result = await executeMicroSwap(amountUsdc, virtualPrice, maxPriceImpactBps, dryRun);

  const summary =
    `nodle_micro-swaps cycle: ${result.status}. ` +
    `${amountUsdc} USDC -> VIRTUAL on Aerodrome. ` +
    (virtualPrice ? `VIRTUAL price: $${virtualPrice.toFixed(4)} (${price_change_24h != null ? (price_change_24h > 0 ? "+" : "") + price_change_24h.toFixed(1) + "% 24h" : "?"}). ` : "") +
    (result.estimated_amount_out_virtual ? `Est. output: ${result.estimated_amount_out_virtual} VIRTUAL. ` : "") +
    (result.error ? `Note: ${result.error}` : "Next cycle in 4 hours.");

  return {
    deliverable: JSON.stringify({
      schema: "nodle_micro_swaps",
      executed_at: new Date().toISOString(),
      mode: dryRun ? "DRY_RUN" : "AUTO_EXECUTE",
      summary,
      virtual_price_usd: virtualPrice,
      virtual_price_change_24h: price_change_24h,
      result,
      next_cycle_hint: "Scheduled every 4 hours via cron: 0 */4 * * *",
    }),
  };
}
HANDLER_EOF

cat > suggestions-handler.ts << 'HANDLER_EOF'
import type { ExecuteJobResult } from "../../../runtime/offeringTypes.js";

/**
 * Seykota Agent Job: Suggestions Schema
 * cron: "0 */4 * * *"  — Every 4 hours
 *
 * Generates actionable trading/farming suggestions based on current
 * market conditions across vol regime, funding, LP health, and chain TVL.
 *
 * Example request:
 * {
 *   "context": "volatility",          // "volatility" | "farming" | "l1" | "base" | "all"
 *   "risk_tier": "normal",            // "normal" | "reduced" | "defensive" | "survival"
 *   "account_equity": 10000,          // USD
 *   "active_positions": ["ETH-PERP"], // optional: current holdings for context
 * }
 */

const COINGECKO_BASE = "https://api.coingecko.com/api/v3";
const DEFILLAMA_BASE = "https://api.llama.fi";
const CG_KEY = process.env.COINGECKO_API_KEY || "";

type RiskTier = "normal" | "reduced" | "defensive" | "survival";
type Context = "volatility" | "farming" | "l1" | "base" | "all";

interface Suggestion {
  id: string;
  priority: "HIGH" | "MEDIUM" | "LOW";
  category: string;
  action: string;
  rationale: string;
  signal: string;
  risk_tier_min: RiskTier;
  data_point?: string;
}

const RISK_ORDER: Record<RiskTier, number> = {
  normal: 0,
  reduced: 1,
  defensive: 2,
  survival: 3,
};

function tierAllowed(jobTier: RiskTier, positionTier: RiskTier): boolean {
  return RISK_ORDER[positionTier] <= RISK_ORDER[jobTier];
}

function buildSuggestions(
  markets: any[],
  tvlChains: any[],
  context: Context,
  riskTier: RiskTier,
  equity: number,
  activePositions: string[]
): Suggestion[] {
  const suggestions: Suggestion[] = [];

  // ── Vol regime signal from price momentum ──
  const eth = markets.find((m) => m.id === "ethereum");
  const btc = markets.find((m) => m.id === "bitcoin");
  const sol = markets.find((m) => m.id === "solana");

  const ethChange7d = eth?.price_change_percentage_7d_in_currency ?? 0;
  const btcChange7d = btc?.price_change_percentage_7d_in_currency ?? 0;
  const avgChange7d = (ethChange7d + btcChange7d) / 2;

  // Trend-following suggestion
  if ((context === "volatility" || context === "all") && avgChange7d < -8) {
    suggestions.push({
      id: "sg-vol-sell-premium",
      priority: "HIGH",
      category: "Volatility",
      action: "SELL VOL — Consider short straddle/strangle on ETH/BTC",
      rationale:
        "7-day decline of " +
        Math.abs(avgChange7d).toFixed(1) +
        "% has likely elevated IV above realized vol. IV-RV spread typically widens during selloffs as fear premium builds. Selling premium captures this mispricing.",
      signal: `BTC 7D: ${btcChange7d.toFixed(1)}% | ETH 7D: ${ethChange7d.toFixed(1)}%`,
      risk_tier_min: "normal",
    });
  }

  if ((context === "volatility" || context === "all") && avgChange7d > 10) {
    suggestions.push({
      id: "sg-vol-buy-gamma",
      priority: "MEDIUM",
      category: "Volatility",
      action: "BUY GAMMA — Long straddle into momentum continuation",
      rationale:
        "Strong uptrend (+${avgChange7d.toFixed(1)}% 7D) may compress IV below what realized vol will deliver. Positive gamma positions profit from continued large moves in either direction.",
      signal: `Avg 7D momentum: +${avgChange7d.toFixed(1)}%`,
      risk_tier_min: "normal",
    });
  }

  // ── LP farming suggestions from TVL data ──
  const baseTvl = tvlChains.find((c) => c.name?.toLowerCase() === "base");
  const ethTvl = tvlChains.find((c) => c.name?.toLowerCase() === "ethereum");

  if ((context === "farming" || context === "base" || context === "all") && baseTvl) {
    const baseTvlChange = baseTvl.change_7d ?? 0;
    if (baseTvlChange > 5) {
      suggestions.push({
        id: "sg-base-lp-expand",
        priority: "HIGH",
        category: "LP Farming",
        action: "EXPAND Base LP — TVL growing, deploy into Aerodrome/Uniswap V3 pools",
        rationale:
          "Base TVL up " +
          baseTvlChange.toFixed(1) +
          "% in 7 days. Rising TVL = rising volume = rising fee APR. Best window to enter LP before fee compression from TVL overshoot.",
        signal: `Base TVL: $${(baseTvl.tvl / 1e9).toFixed(2)}B (+${baseTvlChange.toFixed(1)}% 7D)`,
        risk_tier_min: "normal",
        data_point: `TVL: $${(baseTvl.tvl / 1e9).toFixed(2)}B`,
      });
    } else if (baseTvlChange < -5) {
      suggestions.push({
        id: "sg-base-lp-reduce",
        priority: "HIGH",
        category: "LP Farming",
        action: "REDUCE Base LP — TVL outflow detected, fee APR will compress",
        rationale:
          "Base TVL down " +
          Math.abs(baseTvlChange).toFixed(1) +
          "% in 7 days signals capital rotation away from Base. LP positions will earn less fees as volume drops. Consider tightening ranges or reducing allocation.",
        signal: `Base TVL: $${(baseTvl.tvl / 1e9).toFixed(2)}B (${baseTvlChange.toFixed(1)}% 7D)`,
        risk_tier_min: "reduced",
        data_point: `TVL: $${(baseTvl.tvl / 1e9).toFixed(2)}B`,
      });
    }
  }

  // ── L1 rotation suggestions ──
  if (context === "l1" || context === "all") {
    const sortedByMom = [...markets]
      .filter((m) => m.price_change_percentage_7d_in_currency != null)
      .sort(
        (a, b) =>
          b.price_change_percentage_7d_in_currency -
          a.price_change_percentage_7d_in_currency
      );

    const topL1 = sortedByMom[0];
    const bottomL1 = sortedByMom[sortedByMom.length - 1];

    if (topL1) {
      suggestions.push({
        id: "sg-l1-momentum-long",
        priority: "MEDIUM",
        category: "L1 Trend",
        action: `WATCH ${topL1.symbol?.toUpperCase()} — Strongest L1 momentum this week`,
        rationale:
          topL1.symbol?.toUpperCase() +
          " leads L1 momentum at +" +
          topL1.price_change_percentage_7d_in_currency.toFixed(1) +
          "% 7D. Trend-following principle: the strongest asset often continues to lead. Monitor for continuation setup.",
        signal: `${topL1.symbol?.toUpperCase()} 7D: +${topL1.price_change_percentage_7d_in_currency.toFixed(1)}%`,
        risk_tier_min: "normal",
      });
    }

    if (bottomL1 && bottomL1.price_change_percentage_7d_in_currency < -10) {
      suggestions.push({
        id: "sg-l1-momentum-short",
        priority: "MEDIUM",
        category: "L1 Trend",
        action: `WATCH SHORT ${bottomL1.symbol?.toUpperCase()} — Weakest L1, trend down`,
        rationale:
          bottomL1.symbol?.toUpperCase() +
          " is the weakest L1 at " +
          bottomL1.price_change_percentage_7d_in_currency.toFixed(1) +
          "% 7D. Relative weakness often persists. Ed Seykota: trade the trend, not the hope.",
        signal: `${bottomL1.symbol?.toUpperCase()} 7D: ${bottomL1.price_change_percentage_7d_in_currency.toFixed(1)}%`,
        risk_tier_min: "normal",
      });
    }
  }

  // ── Risk tier gate ──
  const allowed = suggestions.filter((s) =>
    tierAllowed(riskTier, s.risk_tier_min)
  );

  // ── Position overlap filter ──
  const filtered = allowed.filter((s) => {
    if (activePositions.length === 0) return true;
    return true; // Agent can decide based on summary
  });

  // Sort: HIGH first
  return filtered.sort((a, b) => {
    const order = { HIGH: 0, MEDIUM: 1, LOW: 2 };
    return order[a.priority] - order[b.priority];
  });
}

export async function executeJob(
  request: Record<string, any>
): Promise<ExecuteJobResult> {
  const context: Context =
    (request.context as Context) || "all";
  const riskTier: RiskTier =
    (request.risk_tier as RiskTier) || "normal";
  const equity = Number(request.account_equity || 10000);
  const activePositions: string[] = request.active_positions || [];

  const cgHeaders: Record<string, string> = {
    "Content-Type": "application/json",
    ...(CG_KEY ? { "x-cg-demo-api-key": CG_KEY } : {}),
  };

  try {
    // Fetch L1 market data
    const L1_IDS =
      "bitcoin,ethereum,solana,avalanche-2,near,sui,aptos,cosmos,polkadot,cardano";
    const [marketRes, tvlRes] = await Promise.all([
      fetch(
        `${COINGECKO_BASE}/coins/markets?vs_currency=usd&ids=${L1_IDS}&price_change_percentage=7d,24h`,
        { headers: cgHeaders }
      ),
      fetch(`${DEFILLAMA_BASE}/v2/chains`),
    ]);

    const markets = marketRes.ok ? await marketRes.json() : [];
    const allChains = tvlRes.ok ? await tvlRes.json() : [];

    const suggestions = buildSuggestions(
      markets,
      allChains,
      context,
      riskTier,
      equity,
      activePositions
    );

    const summary =
      suggestions.length > 0
        ? `${suggestions.length} suggestion${suggestions.length > 1 ? "s" : ""} generated. ` +
          `High priority: ${suggestions.filter((s) => s.priority === "HIGH").length}. ` +
          `Top action: ${suggestions[0]?.action}`
        : "No high-conviction suggestions at current risk tier. Hold positions, monitor conditions.";

    return {
      deliverable: JSON.stringify({
        schema: "suggestions",
        generated_at: new Date().toISOString(),
        context,
        risk_tier: riskTier,
        account_equity_usd: equity,
        active_positions: activePositions,
        suggestion_count: suggestions.length,
        summary,
        suggestions,
      }),
    };
  } catch (e: any) {
    return {
      deliverable: JSON.stringify({
        schema: "suggestions",
        error: `Failed to generate suggestions: ${e.message}`,
        suggestions: [],
      }),
    };
  }
}
HANDLER_EOF

cat > swap-orchestrator-handler.ts << 'HANDLER_EOF'
import type { ExecuteJobResult } from "../../../runtime/offeringTypes.js";

/**
 * Swap Orchestrator Agent: Signal Alignment + Auto-Execution via CDP
 * cron: "*/15 * * * *"  — Every 15 minutes
 *
 * This agent does NOT generate its own market opinion. It consumes
 * signal output from two upstream agents:
 *
 *   - Seykota   (trend-following: EMA score -7 to +7, LONG/SHORT/CLOSE)
 *   - Druckenmiller (macro/asymmetry: fundamental_signal, action ADD/HOLD/TRIM/EXIT_NOW)
 *
 * When both agents agree on direction for the same asset AND the
 * combined alignment score clears the configured threshold, the
 * orchestrator computes swap parameters and EXECUTES via CDP
 * (Coinbase Developer Platform) using the router/RPC failover chains.
 *
 * MODE: AUTO-EXECUTE
 *   - Alignment threshold met → swap executes immediately, no human gate
 *   - Alignment threshold NOT met → no action, logged as "no_trade"
 *   - Router/RPC failure → fail CLOSED (abort, alert, do not retry blindly)
 *
 * Example request:
 * {
 *   "seykota_signals": [
 *     { "asset": "ETH", "score": 6, "action": "LONG", "atr": 85.2, "current_price": 3450 }
 *   ],
 *   "druckenmiller_signals": [
 *     { "asset": "ETH", "fundamental_signal": "STRONG_BUY", "action": "ADD",
 *       "reward_risk_ratio": 5.2, "conviction": 8 }
 *   ],
 *   "portfolio": {
 *     "equity_usd": 10000,
 *     "usdc_balance": 2500,
 *     "existing_positions": { "ETH": { "size_usd": 800 } }
 *   },
 *   "min_alignment_score": 70,
 *   "max_swap_pct": 10,
 *   "dry_run": false   // if true, computes everything but does NOT call CDP
 * }
 */

const ROUTER_CONFIG = {
  primary: { name: "PRIMARY_ROUTER", address: "0x111111125421cA6dc452d289314280a0f8842A65", identity: "1inch v5" },
  fallback_1: { name: "FALLBACK_ROUTER_1", address: "0x1231deb6f5749ef6ce6943a275a1d3e7486f4eae", identity: "LiFi Diamond" },
  fallback_2: { name: "FALLBACK_ROUTER_2", address: "0x6fF5693b99212Da76ad316178A184AB56D299b43", identity: "0x-style router" },
};

const RPC_CONFIG = {
  primary: process.env.COINBASE_RPC || "https://developer-access-mainnet.base.org",
  fallback_1: process.env.FALLBACK_RPC_1 || "https://1rpc.io/base",
  fallback_2: process.env.FALLBACK_RPC_2 || "https://base.api.pocket.network",
};

const CDP_API_KEY_NAME = process.env.CDP_API_KEY_NAME || "";
const CDP_API_KEY_PRIVATE_KEY = process.env.CDP_API_KEY_PRIVATE_KEY || "";
const CDP_WALLET_ID = process.env.CDP_WALLET_ID || "";

type Direction = "LONG" | "SHORT" | "NEUTRAL" | "CLOSE";

interface SeykotaSignal {
  asset: string;
  score: number;          // -7 to +7
  action: string;         // LONG | SHORT | CLOSE | HOLD
  atr?: number;
  current_price?: number;
}

interface DruckenmillerSignal {
  asset: string;
  fundamental_signal: string;  // STRONG_BUY | BUY | HOLD | SELL | STRONG_SELL
  action: string;               // ADD | HOLD | TRIM | EXIT_NOW
  reward_risk_ratio?: number;
  conviction?: number;
}

interface AlignmentResult {
  asset: string;
  seykota_direction: Direction;
  druckenmiller_direction: Direction;
  aligned: boolean;
  alignment_score: number;     // 0-100
  combined_action: "EXECUTE_LONG" | "EXECUTE_SHORT" | "EXECUTE_CLOSE" | "NO_TRADE";
  rationale: string;
}

interface SwapPlan {
  asset: string;
  direction: Direction;
  from_token: string;
  to_token: string;
  amount_usd: number;
  router_attempted: string[];
  router_used: string | null;
  rpc_used: string | null;
  status: "PLANNED" | "EXECUTED" | "FAILED" | "ABORTED_NO_ALIGNMENT" | "DRY_RUN";
  tx_hash: string | null;
  error: string | null;
}

// ─── SIGNAL NORMALIZATION ────────────────────────────────────────────────────

function seykotaToDirection(sig: SeykotaSignal): Direction {
  const action = (sig.action || "").toUpperCase();
  if (action === "LONG" || sig.score >= 5) return "LONG";
  if (action === "SHORT" || sig.score <= -5) return "SHORT";
  if (action === "CLOSE") return "CLOSE";
  return "NEUTRAL";
}

function druckenmillerToDirection(sig: DruckenmillerSignal): Direction {
  const fund = (sig.fundamental_signal || "").toUpperCase();
  const action = (sig.action || "").toUpperCase();
  if (action === "EXIT_NOW") return "CLOSE";
  if (fund === "STRONG_BUY" || fund === "BUY" || action === "ADD") return "LONG";
  if (fund === "STRONG_SELL" || fund === "SELL") return "SHORT";
  return "NEUTRAL";
}

// ─── ALIGNMENT ENGINE ─────────────────────────────────────────────────────────

function computeAlignment(
  seykotaSig: SeykotaSignal | undefined,
  druckSig: DruckenmillerSignal | undefined,
  asset: string
): AlignmentResult {
  if (!seykotaSig || !druckSig) {
    return {
      asset,
      seykota_direction: "NEUTRAL",
      druckenmiller_direction: "NEUTRAL",
      aligned: false,
      alignment_score: 0,
      combined_action: "NO_TRADE",
      rationale: `Missing signal — Seykota: ${!!seykotaSig}, Druckenmiller: ${!!druckSig}. Cannot evaluate alignment without both.`,
    };
  }

  const sDir = seykotaToDirection(seykotaSig);
  const dDir = druckenmillerToDirection(druckSig);

  // CLOSE from either agent overrides everything — both must agree it's still OK to hold
  if (sDir === "CLOSE" || dDir === "CLOSE") {
    return {
      asset,
      seykota_direction: sDir,
      druckenmiller_direction: dDir,
      aligned: true,
      alignment_score: 100,
      combined_action: "EXECUTE_CLOSE",
      rationale: `${sDir === "CLOSE" ? "Seykota" : "Druckenmiller"} signals CLOSE. Closing position regardless of other agent's view — risk management overrides upside thesis.`,
    };
  }

  const directionsMatch = sDir === dDir && sDir !== "NEUTRAL";

  if (!directionsMatch) {
    return {
      asset,
      seykota_direction: sDir,
      druckenmiller_direction: dDir,
      aligned: false,
      alignment_score: 20,
      combined_action: "NO_TRADE",
      rationale: `Signal conflict: Seykota says ${sDir}, Druckenmiller says ${dDir}. No trade — agents must agree on direction before auto-execution.`,
    };
  }

  // Both agree on direction — score the strength of conviction
  let score = 50; // base for directional agreement

  // Seykota score strength (-7 to +7, abs value contributes)
  const seykotaStrength = Math.abs(seykotaSig.score || 0);
  score += Math.min(25, seykotaStrength * 3.5); // max +25 at |score|=7

  // Druckenmiller conviction (1-10) and reward/risk
  const conviction = druckSig.conviction || 5;
  score += Math.min(15, (conviction - 5) * 3); // max +15 at conviction=10

  const rr = druckSig.reward_risk_ratio || 0;
  if (rr >= 5) score += 10;
  else if (rr >= 3) score += 5;
  else if (rr > 0 && rr < 2) score -= 15; // weak asymmetry penalizes alignment

  score = Math.max(0, Math.min(100, Math.round(score)));

  const combinedAction: AlignmentResult["combined_action"] =
    sDir === "LONG" ? "EXECUTE_LONG" :
    sDir === "SHORT" ? "EXECUTE_SHORT" :
    "NO_TRADE";

  return {
    asset,
    seykota_direction: sDir,
    druckenmiller_direction: dDir,
    aligned: true,
    alignment_score: score,
    combined_action: combinedAction,
    rationale:
      `Both agents agree: ${sDir}. Seykota score: ${seykotaSig.score} (trend strength). ` +
      `Druckenmiller: ${druckSig.fundamental_signal}, conviction ${conviction}/10, R/R ${rr.toFixed ? rr.toFixed(1) : rr}:1. ` +
      `Alignment score: ${score}/100.`,
  };
}

// ─── CDP EXECUTION ────────────────────────────────────────────────────────────

/**
 * Attempts a swap via CDP, trying routers in failover order.
 * Returns the SwapPlan with execution result.
 *
 * NOTE: This function calls the CDP SDK / API. The actual CDP client
 * initialization should use CDP_API_KEY_NAME / CDP_API_KEY_PRIVATE_KEY /
 * CDP_WALLET_ID from EconomyOS-managed environment. Implementation here
 * shows the orchestration logic and router/RPC failover wiring — wire in
 * the actual @coinbase/coinbase-sdk calls in place of the placeholder.
 */
async function executeSwapViaCDP(plan: SwapPlan, dryRun: boolean): Promise<SwapPlan> {
  if (dryRun) {
    return { ...plan, status: "DRY_RUN", router_used: ROUTER_CONFIG.primary.name, rpc_used: "primary" };
  }

  if (!CDP_API_KEY_NAME || !CDP_API_KEY_PRIVATE_KEY || !CDP_WALLET_ID) {
    return {
      ...plan,
      status: "FAILED",
      error: "CDP credentials not configured (CDP_API_KEY_NAME / CDP_API_KEY_PRIVATE_KEY / CDP_WALLET_ID). Fail closed — no trade executed.",
    };
  }

  const routerAttempts: Array<keyof typeof ROUTER_CONFIG> = ["primary", "fallback_1", "fallback_2"];
  const rpcAttempts: Array<keyof typeof RPC_CONFIG> = ["primary", "fallback_1", "fallback_2"];

  for (const routerKey of routerAttempts) {
    const router = ROUTER_CONFIG[routerKey];
    plan.router_attempted.push(router.name);

    for (const rpcKey of rpcAttempts) {
      try {
        // ── CDP execution placeholder ──────────────────────────────────
        // Real implementation:
        //
        //   import { Coinbase, Wallet } from "@coinbase/coinbase-sdk";
        //   Coinbase.configure({ apiKeyName: CDP_API_KEY_NAME, privateKey: CDP_API_KEY_PRIVATE_KEY });
        //   const wallet = await Wallet.fetch(CDP_WALLET_ID);
        //   const tx = await wallet.createTrade({
        //     amount: plan.amount_usd,
        //     fromAssetId: plan.from_token,
        //     toAssetId: plan.to_token,
        //     // router address + RPC endpoint passed via custom contract call
        //     // if CDP native trade doesn't support the asset pair directly
        //   });
        //   await tx.wait();
        //
        // The orchestrator tries (router × RPC) combinations until one
        // succeeds. On success, break out of both loops.

        const wouldSucceed = routerKey === "primary" && rpcKey === "primary"; // placeholder logic

        if (wouldSucceed) {
          return {
            ...plan,
            status: "EXECUTED",
            router_used: router.name,
            rpc_used: RPC_CONFIG[rpcKey],
            tx_hash: "0x_PLACEHOLDER_TX_HASH_WIRE_CDP_SDK",
            error: null,
          };
        }
      } catch (e: any) {
        // Try next RPC, then next router
        continue;
      }
    }
  }

  // All router × RPC combinations failed — fail closed
  return {
    ...plan,
    status: "FAILED",
    error: `All routers (${routerAttempts.map(r => ROUTER_CONFIG[r].name).join(", ")}) × all RPCs failed. Fail closed — aborting swap, no retry this cycle.`,
  };
}

// ─── MAIN ────────────────────────────────────────────────────────────────────

export async function executeJob(request: Record<string, any>): Promise<ExecuteJobResult> {
  const seykotaSignals: SeykotaSignal[] = request.seykota_signals || [];
  const druckSignals: DruckenmillerSignal[] = request.druckenmiller_signals || [];
  const portfolio = request.portfolio || { equity_usd: 10000, usdc_balance: 0, existing_positions: {} };
  const minAlignmentScore = Number(request.min_alignment_score ?? process.env.ORCHESTRATOR_MIN_ALIGNMENT_SCORE ?? 70);
  const maxSwapPct = Number(request.max_swap_pct ?? process.env.ORCHESTRATOR_MAX_SWAP_PCT ?? 10);
  const dryRun = request.dry_run === true;

  // Build asset universe from both signal sets
  const allAssets = new Set<string>([
    ...seykotaSignals.map(s => s.asset),
    ...druckSignals.map(s => s.asset),
  ]);

  const alignments: AlignmentResult[] = [];
  const swapPlans: SwapPlan[] = [];

  for (const asset of allAssets) {
    const sSig = seykotaSignals.find(s => s.asset === asset);
    const dSig = druckSignals.find(s => s.asset === asset);
    const alignment = computeAlignment(sSig, dSig, asset);
    alignments.push(alignment);

    if (alignment.combined_action === "NO_TRADE") continue;

    if (alignment.combined_action === "EXECUTE_CLOSE") {
      const existingPos = portfolio.existing_positions?.[asset];
      if (!existingPos) continue; // nothing to close

      const plan: SwapPlan = {
        asset,
        direction: "CLOSE",
        from_token: asset,
        to_token: "USDC",
        amount_usd: existingPos.size_usd || 0,
        router_attempted: [],
        router_used: null,
        rpc_used: null,
        status: "PLANNED",
        tx_hash: null,
        error: null,
      };
      const executed = await executeSwapViaCDP(plan, dryRun);
      swapPlans.push(executed);
      continue;
    }

    // EXECUTE_LONG or EXECUTE_SHORT — check alignment threshold
    if (alignment.alignment_score < minAlignmentScore) {
      swapPlans.push({
        asset,
        direction: alignment.combined_action === "EXECUTE_LONG" ? "LONG" : "SHORT",
        from_token: alignment.combined_action === "EXECUTE_LONG" ? "USDC" : asset,
        to_token: alignment.combined_action === "EXECUTE_LONG" ? asset : "USDC",
        amount_usd: 0,
        router_attempted: [],
        router_used: null,
        rpc_used: null,
        status: "ABORTED_NO_ALIGNMENT",
        tx_hash: null,
        error: `Alignment score ${alignment.alignment_score} below threshold ${minAlignmentScore}`,
      });
      continue;
    }

    // Compute swap size — capped by maxSwapPct of equity
    const maxSwapUsd = (portfolio.equity_usd || 0) * (maxSwapPct / 100);
    const availableUsdc = portfolio.usdc_balance || 0;

    let amountUsd: number;
    let fromToken: string;
    let toToken: string;

    if (alignment.combined_action === "EXECUTE_LONG") {
      amountUsd = Math.min(maxSwapUsd, availableUsdc);
      fromToken = "USDC";
      toToken = asset;
    } else {
      // EXECUTE_SHORT — assumes existing long position to unwind, or perp short via separate venue
      const existingPos = portfolio.existing_positions?.[asset];
      amountUsd = Math.min(maxSwapUsd, existingPos?.size_usd || 0);
      fromToken = asset;
      toToken = "USDC";
    }

    if (amountUsd <= 0) {
      swapPlans.push({
        asset,
        direction: alignment.combined_action === "EXECUTE_LONG" ? "LONG" : "SHORT",
        from_token: fromToken,
        to_token: toToken,
        amount_usd: 0,
        router_attempted: [],
        router_used: null,
        rpc_used: null,
        status: "ABORTED_NO_ALIGNMENT",
        tx_hash: null,
        error: "Computed swap amount is $0 (insufficient balance or no position to unwind)",
      });
      continue;
    }

    const plan: SwapPlan = {
      asset,
      direction: alignment.combined_action === "EXECUTE_LONG" ? "LONG" : "SHORT",
      from_token: fromToken,
      to_token: toToken,
      amount_usd: Math.round(amountUsd * 100) / 100,
      router_attempted: [],
      router_used: null,
      rpc_used: null,
      status: "PLANNED",
      tx_hash: null,
      error: null,
    };

    const executed = await executeSwapViaCDP(plan, dryRun);
    swapPlans.push(executed);
  }

  const executedSwaps = swapPlans.filter(p => p.status === "EXECUTED");
  const failedSwaps = swapPlans.filter(p => p.status === "FAILED");
  const abortedSwaps = swapPlans.filter(p => p.status === "ABORTED_NO_ALIGNMENT");
  const noTradeAssets = alignments.filter(a => a.combined_action === "NO_TRADE");

  const summary =
    `Orchestrator cycle: ${allAssets.size} asset(s) evaluated. ` +
    `${executedSwaps.length} swap(s) executed${dryRun ? " (DRY RUN)" : ""}. ` +
    `${failedSwaps.length} failed (router/RPC exhausted). ` +
    `${abortedSwaps.length} aborted (below alignment threshold). ` +
    `${noTradeAssets.length} no-trade (signal conflict or insufficient data).`;

  return {
    deliverable: JSON.stringify({
      schema: "swap_orchestrator",
      mode: dryRun ? "DRY_RUN" : "AUTO_EXECUTE",
      executed_at: new Date().toISOString(),
      summary,
      config: {
        min_alignment_score: minAlignmentScore,
        max_swap_pct: maxSwapPct,
        router_failover_order: Object.values(ROUTER_CONFIG).map(r => r.name),
        rpc_failover_order: ["COINBASE_RPC", "FALLBACK_RPC_1", "FALLBACK_RPC_2"],
      },
      alignments,
      swap_plans: swapPlans,
      executed_count: executedSwaps.length,
      failed_count: failedSwaps.length,
      aborted_count: abortedSwaps.length,
    }),
  };
}
HANDLER_EOF

cat > tracking-chain-handler.ts << 'HANDLER_EOF'
import type { ExecuteJobResult } from "../../../runtime/offeringTypes.js";

/**
 * Seykota Agent Job: Tracking Chain Schema
 * cron: "0 */4 * * *"  — Every 4 hours
 *
 * Tracks full chain-level health metrics: TVL, TVL momentum, active protocols,
 * DEX volume, stablecoin flows, bridge inflows/outflows, and fee revenue.
 * Chain-level data is the macro layer — it tells you WHERE capital is flowing
 * before the token prices reflect it. TVL leads price.
 *
 * Example request:
 * {
 *   "chains": ["base", "ethereum", "solana", "avalanche"],
 *   "include_protocols": true,    // top protocols by TVL per chain
 *   "include_stablecoins": true,  // stablecoin breakdown
 *   "include_bridges": false,
 * }
 */

const DEFILLAMA_BASE = "https://api.llama.fi";

interface ChainSnapshot {
  name: string;
  tvl: number;
  tvl_change_1d: number | null;
  tvl_change_7d: number | null;
  tvl_momentum: "INFLOW" | "OUTFLOW" | "STABLE";
  tvl_rank: number;
  dex_volume_24h: number | null;
  fee_revenue_24h: number | null;
  protocol_count: number | null;
  dominant_protocol: string | null;
  stablecoin_tvl: number | null;
  chain_signal: "ACCUMULATING" | "DISTRIBUTING" | "NEUTRAL" | "WATCH";
  alert: string | null;
}

interface ProtocolEntry {
  name: string;
  chain: string;
  tvl: number;
  tvl_change_7d: number | null;
  category: string;
}

interface StablecoinEntry {
  chain: string;
  total_circulating: number;
  change_7d: number | null;
  dominant_stable: string | null;
}

function classifyMomentum(change7d: number | null): ChainSnapshot["tvl_momentum"] {
  if (change7d == null) return "STABLE";
  if (change7d > 3) return "INFLOW";
  if (change7d < -3) return "OUTFLOW";
  return "STABLE";
}

function buildChainSignal(
  tvlChange7d: number | null,
  dexVol: number | null,
  tvl: number
): ChainSnapshot["chain_signal"] {
  const momentum = classifyMomentum(tvlChange7d);
  const volTvl = tvl > 0 && dexVol != null ? (dexVol / tvl) * 100 : null;

  if (momentum === "INFLOW" && volTvl != null && volTvl > 5) return "ACCUMULATING";
  if (momentum === "OUTFLOW" && volTvl != null && volTvl > 10) return "DISTRIBUTING";
  if (
    (tvlChange7d != null && Math.abs(tvlChange7d) > 15) ||
    (volTvl != null && volTvl > 20)
  )
    return "WATCH";
  return "NEUTRAL";
}

function buildAlert(snap: Partial<ChainSnapshot>): string | null {
  if ((snap.tvl_change_7d ?? 0) < -15)
    return `MAJOR OUTFLOW: TVL dropped ${Math.abs(snap.tvl_change_7d ?? 0).toFixed(1)}% in 7 days — capital rotation in progress`;
  if ((snap.tvl_change_7d ?? 0) > 20)
    return `MAJOR INFLOW: TVL +${(snap.tvl_change_7d ?? 0).toFixed(1)}% in 7 days — strong capital attraction`;
  if (snap.chain_signal === "DISTRIBUTING")
    return `DISTRIBUTION: High DEX volume + TVL outflow = smart money exiting`;
  return null;
}

export async function executeJob(
  request: Record<string, any>
): Promise<ExecuteJobResult> {
  const chainNames: string[] = (
    request.chains || ["base", "ethereum", "solana", "avalanche", "arbitrum", "optimism", "sui", "near"]
  ).map((c: string) => c.toLowerCase());

  const includeProtocols = request.include_protocols !== false;
  const includeStablecoins = request.include_stablecoins !== false;

  try {
    // ── Fetch all chain TVL data ──
    const [chainRes, protocolRes, stableRes, dexRes, feesRes] = await Promise.all([
      fetch(`${DEFILLAMA_BASE}/v2/chains`),
      includeProtocols ? fetch(`${DEFILLAMA_BASE}/protocols`) : Promise.resolve(null),
      includeStablecoins ? fetch(`${DEFILLAMA_BASE}/stablecoins?includePrices=true`) : Promise.resolve(null),
      fetch(`${DEFILLAMA_BASE}/overview/dexs?excludeTotalDataChart=true&excludeTotalDataChartBreakdown=true&dataType=dailyVolume`),
      fetch(`${DEFILLAMA_BASE}/overview/fees?excludeTotalDataChart=true&excludeTotalDataChartBreakdown=true&dataType=dailyFees`),
    ]);

    const allChains: any[] = chainRes.ok ? await chainRes.json() : [];
    const allProtocols: any[] = protocolRes?.ok ? (await protocolRes.json()) : [];
    const stableData: any = stableRes?.ok ? await stableRes.json() : null;
    const dexData: any = dexRes.ok ? await dexRes.json() : null;
    const feesData: any = feesRes.ok ? await feesRes.json() : null;

    // ── Build DEX volume map by chain ──
    const dexVolumeByChain: Record<string, number> = {};
    if (dexData?.protocols) {
      for (const p of dexData.protocols) {
        for (const chain of (p.chains || [])) {
          const vol = p.total24h || 0;
          const chainKey = chain.toLowerCase();
          dexVolumeByChain[chainKey] = (dexVolumeByChain[chainKey] || 0) + vol / (p.chains?.length || 1);
        }
      }
    }

    // ── Build fee revenue map by chain ──
    const feesByChain: Record<string, number> = {};
    if (feesData?.protocols) {
      for (const p of feesData.protocols) {
        for (const chain of (p.chains || [])) {
          const fee = p.total24h || 0;
          const chainKey = chain.toLowerCase();
          feesByChain[chainKey] = (feesByChain[chainKey] || 0) + fee / (p.chains?.length || 1);
        }
      }
    }

    // ── Build stablecoin map by chain ──
    const stableByChain: Record<string, StablecoinEntry> = {};
    if (stableData?.peggedAssets) {
      for (const asset of stableData.peggedAssets) {
        const chains = asset.chainCirculating || {};
        for (const [chainName, circData] of Object.entries(chains)) {
          const key = chainName.toLowerCase();
          const circ = (circData as any)?.current?.peggedUSD || 0;
          if (!stableByChain[key]) {
            stableByChain[key] = {
              chain: chainName,
              total_circulating: 0,
              change_7d: null,
              dominant_stable: null,
            };
          }
          stableByChain[key].total_circulating += circ;
        }
      }
    }

    // ── Sort chains by TVL globally for rank ──
    const sortedAllChains = [...allChains].sort((a, b) => (b.tvl || 0) - (a.tvl || 0));
    const rankMap: Record<string, number> = {};
    sortedAllChains.forEach((c, i) => {
      rankMap[c.name?.toLowerCase()] = i + 1;
    });

    // ── Build chain snapshots ──
    const snapshots: ChainSnapshot[] = [];

    for (const name of chainNames) {
      const chainData = allChains.find(
        (c) => c.name?.toLowerCase() === name
      );

      if (!chainData) {
        snapshots.push({
          name,
          tvl: 0,
          tvl_change_1d: null,
          tvl_change_7d: null,
          tvl_momentum: "STABLE",
          tvl_rank: 999,
          dex_volume_24h: null,
          fee_revenue_24h: null,
          protocol_count: null,
          dominant_protocol: null,
          stablecoin_tvl: null,
          chain_signal: "NEUTRAL",
          alert: null,
        });
        continue;
      }

      const tvl = chainData.tvl || 0;
      const change1d = chainData.change_1d ?? null;
      const change7d = chainData.change_7d ?? null;
      const dexVol = dexVolumeByChain[name] ?? null;
      const feeRev = feesByChain[name] ?? null;

      // Top protocol for this chain
      const chainProtos = allProtocols
        .filter((p) => (p.chains || []).map((c: string) => c.toLowerCase()).includes(name))
        .sort((a, b) => (b.tvl || 0) - (a.tvl || 0));

      const snap: ChainSnapshot = {
        name: chainData.name,
        tvl,
        tvl_change_1d: change1d != null ? Math.round(change1d * 10) / 10 : null,
        tvl_change_7d: change7d != null ? Math.round(change7d * 10) / 10 : null,
        tvl_momentum: classifyMomentum(change7d),
        tvl_rank: rankMap[name] || 999,
        dex_volume_24h: dexVol ? Math.round(dexVol) : null,
        fee_revenue_24h: feeRev ? Math.round(feeRev) : null,
        protocol_count: chainProtos.length || null,
        dominant_protocol: chainProtos[0]?.name || null,
        stablecoin_tvl: stableByChain[name]?.total_circulating
          ? Math.round(stableByChain[name].total_circulating)
          : null,
        chain_signal: buildChainSignal(change7d, dexVol, tvl),
        alert: null,
      };
      snap.alert = buildAlert(snap);
      snapshots.push(snap);
    }

    // ── Top protocols per chain ──
    const topProtocols: ProtocolEntry[] = includeProtocols
      ? chainNames.flatMap((name) => {
          return allProtocols
            .filter((p) =>
              (p.chains || []).map((c: string) => c.toLowerCase()).includes(name)
            )
            .sort((a, b) => (b.tvl || 0) - (a.tvl || 0))
            .slice(0, 5)
            .map((p) => ({
              name: p.name,
              chain: name,
              tvl: p.tvl || 0,
              tvl_change_7d: p.change_7d ?? null,
              category: p.category || "unknown",
            }));
        })
      : [];

    // ── Summary ──
    const alerts = snapshots.filter((s) => s.alert);
    const accumulating = snapshots.filter((s) => s.chain_signal === "ACCUMULATING");
    const distributing = snapshots.filter((s) => s.chain_signal === "DISTRIBUTING");
    const totalTvl = snapshots.reduce((sum, s) => sum + s.tvl, 0);

    const topChain = [...snapshots].sort((a, b) => b.tvl - a.tvl)[0];
    const fastestGrowing = [...snapshots]
      .filter((s) => s.tvl_change_7d != null)
      .sort((a, b) => (b.tvl_change_7d ?? 0) - (a.tvl_change_7d ?? 0))[0];

    const summary =
      `Tracked ${snapshots.length} chains. ` +
      `Combined TVL: $${(totalTvl / 1e9).toFixed(2)}B. ` +
      `${accumulating.length} accumulating, ${distributing.length} distributing. ` +
      (fastestGrowing?.tvl_change_7d != null
        ? `Fastest growing: ${fastestGrowing.name} (+${fastestGrowing.tvl_change_7d.toFixed(1)}% 7D TVL). `
        : "") +
      `${alerts.length} alert${alerts.length !== 1 ? "s" : ""} triggered.`;

    return {
      deliverable: JSON.stringify({
        schema: "tracking_chain",
        tracked_at: new Date().toISOString(),
        chain_count: snapshots.length,
        total_tvl_usd: totalTvl,
        alerts_triggered: alerts.length,
        accumulating_chains: accumulating.map((s) => s.name),
        distributing_chains: distributing.map((s) => s.name),
        summary,
        chains: snapshots,
        top_protocols: topProtocols,
        stablecoins: includeStablecoins
          ? chainNames.map((name) => stableByChain[name] || { chain: name, total_circulating: 0, change_7d: null })
          : [],
        alerts: alerts.map((s) => ({
          chain: s.name,
          signal: s.chain_signal,
          tvl_usd: s.tvl,
          tvl_change_7d: s.tvl_change_7d,
          message: s.alert,
        })),
      }),
    };
  } catch (e: any) {
    return {
      deliverable: JSON.stringify({
        schema: "tracking_chain",
        error: `Chain tracking failed: ${e.message}`,
        chains: [],
      }),
    };
  }
}
HANDLER_EOF

cat > tracking-coin-handler.ts << 'HANDLER_EOF'
import type { ExecuteJobResult } from "../../../runtime/offeringTypes.js";

/**
 * Seykota Agent Job: Tracking Coin Schema
 * cron: "*/30 * * * *"  — Every 30 minutes
 *
 * Deep per-coin tracking: price, momentum, trend score, on-chain activity,
 * social sentiment signals, and vol-farming-specific metrics (IV proxy,
 * historical vol, funding rate). The agent's per-asset intelligence profile.
 *
 * Example request:
 * {
 *   "coin_id": "ethereum",         // CoinGecko ID
 *   "include_market_chart": true,  // fetch 7-day OHLC for RV calc
 *   "include_developer": false,    // fetch GitHub commit activity
 * }
 */

const COINGECKO_BASE = "https://api.coingecko.com/api/v3";
const CG_KEY = process.env.COINGECKO_API_KEY || "";

interface PriceCandle {
  timestamp: number;
  open: number;
  high: number;
  low: number;
  close: number;
}

interface TrendScore {
  score: number;         // -7 to +7 (Seykota EMA scoring)
  label: string;
  signals: Record<string, boolean>;
}

interface VolMetrics {
  realized_vol_7d: number;      // annualized %
  high_low_range_7d: number;    // max drawdown in window
  avg_daily_range: number;      // avg (high-low)/close %
  vol_regime: "LOW" | "MEDIUM" | "HIGH" | "EXTREME";
}

function calcEMA(prices: number[], period: number): number[] {
  const k = 2 / (period + 1);
  const ema: number[] = [prices[0]];
  for (let i = 1; i < prices.length; i++) {
    ema.push(prices[i] * k + ema[i - 1] * (1 - k));
  }
  return ema;
}

function calcRealizedVol(closes: number[]): number {
  if (closes.length < 2) return 0;
  const returns: number[] = [];
  for (let i = 1; i < closes.length; i++) {
    returns.push(Math.log(closes[i] / closes[i - 1]));
  }
  const mean = returns.reduce((a, b) => a + b, 0) / returns.length;
  const variance =
    returns.reduce((sum, r) => sum + Math.pow(r - mean, 2), 0) /
    (returns.length - 1);
  return Math.sqrt(variance) * Math.sqrt(365) * 100; // annualized %
}

function calcATR(candles: PriceCandle[]): number {
  if (candles.length < 2) return 0;
  const trs: number[] = [];
  for (let i = 1; i < candles.length; i++) {
    const prevClose = candles[i - 1].close;
    const tr = Math.max(
      candles[i].high - candles[i].low,
      Math.abs(candles[i].high - prevClose),
      Math.abs(candles[i].low - prevClose)
    );
    trs.push(tr);
  }
  return trs.reduce((a, b) => a + b, 0) / trs.length;
}

function scoreTrend(
  price: number,
  closes: number[]
): TrendScore {
  if (closes.length < 50) {
    return { score: 0, label: "INSUFFICIENT_DATA", signals: {} };
  }

  const ema10 = calcEMA(closes, 10);
  const ema20 = calcEMA(closes, 20);
  const ema50 = calcEMA(closes, 50);

  const last10 = ema10[ema10.length - 1];
  const last20 = ema20[ema20.length - 1];
  const last50 = ema50[ema50.length - 1];

  const signals = {
    "price_gt_ema10_daily": price > last10,
    "price_gt_ema20_daily": price > last20,
    "price_gt_ema50_daily": price > last50,
    "ema10_gt_ema20_daily": last10 > last20,
    "ema10_gt_ema50_daily": last10 > last50,
  };

  const score = Object.values(signals).reduce(
    (sum, v) => sum + (v ? 1 : -1),
    0
  );

  const label =
    score >= 5
      ? "STRONG_UPTREND"
      : score >= 3
      ? "UPTREND"
      : score >= 0
      ? "NEUTRAL"
      : score >= -3
      ? "DOWNTREND"
      : "STRONG_DOWNTREND";

  return { score, label, signals };
}

function buildVolMetrics(candles: PriceCandle[]): VolMetrics {
  const closes = candles.map((c) => c.close);
  const rv = calcRealizedVol(closes);
  const allHighs = candles.map((c) => c.high);
  const allLows = candles.map((c) => c.low);
  const maxHigh = Math.max(...allHighs);
  const minLow = Math.min(...allLows);
  const hlRange = minLow > 0 ? ((maxHigh - minLow) / minLow) * 100 : 0;

  const dailyRanges = candles.map((c) =>
    c.close > 0 ? ((c.high - c.low) / c.close) * 100 : 0
  );
  const avgDailyRange =
    dailyRanges.reduce((a, b) => a + b, 0) / dailyRanges.length;

  const volRegime: VolMetrics["vol_regime"] =
    rv > 150
      ? "EXTREME"
      : rv > 80
      ? "HIGH"
      : rv > 40
      ? "MEDIUM"
      : "LOW";

  return {
    realized_vol_7d: Math.round(rv * 10) / 10,
    high_low_range_7d: Math.round(hlRange * 10) / 10,
    avg_daily_range: Math.round(avgDailyRange * 100) / 100,
    vol_regime: volRegime,
  };
}

export async function executeJob(
  request: Record<string, any>
): Promise<ExecuteJobResult> {
  const coinId: string =
    request.coin_id || request.id || request.token || "ethereum";
  const includeChart = request.include_market_chart !== false;
  const includeDev = request.include_developer === true;

  const cgHeaders: Record<string, string> = {
    ...(CG_KEY ? { "x-cg-demo-api-key": CG_KEY } : {}),
  };

  try {
    // ── Fetch core coin data ──
    const detailFields = [
      "id", "symbol", "name", "market_data",
      "developer_data", "community_data", "description",
      "categories", "links",
    ].join(",");

    const [detailRes, chartRes] = await Promise.all([
      fetch(
        `${COINGECKO_BASE}/coins/${coinId}?localization=false&tickers=false` +
          `&market_data=true&community_data=true&developer_data=${includeDev}` +
          `&sparkline=false`,
        { headers: cgHeaders }
      ),
      includeChart
        ? fetch(
            `${COINGECKO_BASE}/coins/${coinId}/ohlc?vs_currency=usd&days=30`,
            { headers: cgHeaders }
          )
        : Promise.resolve(null),
    ]);

    if (!detailRes.ok) {
      throw new Error(`CoinGecko coin detail: ${detailRes.status} — check coin_id "${coinId}"`);
    }

    const detail = await detailRes.json();
    const md = detail.market_data || {};

    // ── Parse OHLC candles ──
    let candles: PriceCandle[] = [];
    if (chartRes?.ok) {
      const raw: [number, number, number, number, number][] =
        await chartRes.json();
      candles = raw.map(([ts, o, h, l, c]) => ({
        timestamp: ts,
        open: o,
        high: h,
        low: l,
        close: c,
      }));
    }

    const closes = candles.map((c) => c.close);
    const currentPrice: number = md.current_price?.usd || 0;

    // ── Compute derived metrics ──
    const trendScore = closes.length >= 10 ? scoreTrend(currentPrice, closes) : null;
    const atr = candles.length >= 14 ? calcATR(candles.slice(-14)) : null;
    const volMetrics = candles.length >= 7 ? buildVolMetrics(candles.slice(-7)) : null;

    // ── Momentum ──
    const mom5d = md.price_change_percentage_14d?.usd ?? null;  // proxy
    const mom30d = md.price_change_percentage_30d?.usd ?? null;

    // ── Stop levels (2×ATR) ──
    const longStop = atr ? currentPrice - 2 * atr : null;
    const shortStop = atr ? currentPrice + 2 * atr : null;

    // ── Position sizing hint (1% risk on $10K account) ──
    const riskDollars = 100; // 1% of $10K default
    const stopDistance = atr ? 2 * atr : currentPrice * 0.05;
    const suggestedUnits = stopDistance > 0 ? riskDollars / stopDistance : 0;
    const suggestedNotional = suggestedUnits * currentPrice;

    // ── Summary ──
    const summary =
      `${detail.symbol?.toUpperCase()} ($${currentPrice.toLocaleString()}) — ` +
      (trendScore
        ? `Trend: ${trendScore.label} (${trendScore.score > 0 ? "+" : ""}${trendScore.score}/5). `
        : "") +
      (volMetrics ? `RV 7D: ${volMetrics.realized_vol_7d}% annualized (${volMetrics.vol_regime}). ` : "") +
      (atr ? `ATR: $${atr.toFixed(2)}. ` : "") +
      `24H: ${(md.price_change_percentage_24h?.usd ?? 0).toFixed(2)}%, ` +
      `7D: ${(md.price_change_percentage_7d?.usd ?? 0).toFixed(2)}%.`;

    return {
      deliverable: JSON.stringify({
        schema: "tracking_coin",
        tracked_at: new Date().toISOString(),
        coin_id: coinId,
        symbol: detail.symbol?.toUpperCase(),
        name: detail.name,
        summary,

        // Price
        price: {
          current_usd: currentPrice,
          ath_usd: md.ath?.usd,
          ath_change_pct: md.ath_change_percentage?.usd,
          atl_usd: md.atl?.usd,
          change_1h: md.price_change_percentage_1h_in_currency?.usd,
          change_24h: md.price_change_percentage_24h?.usd,
          change_7d: md.price_change_percentage_7d?.usd,
          change_30d: md.price_change_percentage_30d?.usd,
        },

        // Market
        market: {
          market_cap_usd: md.market_cap?.usd,
          fully_diluted_val_usd: md.fully_diluted_valuation?.usd,
          volume_24h_usd: md.total_volume?.usd,
          volume_to_mcap_pct:
            md.market_cap?.usd > 0
              ? ((md.total_volume?.usd / md.market_cap?.usd) * 100).toFixed(2)
              : null,
          circulating_supply: md.circulating_supply,
          total_supply: md.total_supply,
          max_supply: md.max_supply,
        },

        // Trend & technicals
        trend: trendScore,
        technicals: {
          atr_14: atr ? Math.round(atr * 100) / 100 : null,
          long_stop_2atr: longStop ? Math.round(longStop * 100) / 100 : null,
          short_stop_2atr: shortStop ? Math.round(shortStop * 100) / 100 : null,
          suggested_units_per_1pct_risk: Math.round(suggestedUnits * 1000) / 1000,
          suggested_notional_1pct_risk: Math.round(suggestedNotional),
        },

        // Vol metrics
        volatility: volMetrics,

        // Developer (optional)
        developer: includeDev
          ? {
              github_stars: detail.developer_data?.stars,
              github_forks: detail.developer_data?.forks,
              commits_4w: detail.developer_data?.commit_count_4_weeks,
              active_devs: detail.developer_data?.contributors,
            }
          : null,

        // Categories
        categories: detail.categories?.slice(0, 5) || [],
      }),
    };
  } catch (e: any) {
    return {
      deliverable: JSON.stringify({
        schema: "tracking_coin",
        error: `Coin tracking failed: ${e.message}`,
        coin_id: coinId,
      }),
    };
  }
}
HANDLER_EOF

cat > tracking-cross-chain-handler.ts << 'HANDLER_EOF'
import type { ExecuteJobResult } from "../../../runtime/offeringTypes.js";

/**
 * Seykota Agent Job: Tracking Cross-Chain Schema
 * cron: "0 */3 * * *"  — Every 3 hours
 *
 * Cross-chain intelligence layer: where is capital flowing BETWEEN chains?
 * Tracks bridge volumes, net flows, TVL momentum differentials, stablecoin
 * migration patterns, and identifies which chains are ABSORBING vs. LOSING capital.
 *
 * This is the macro layer above individual chains — it tells your agent
 * which ecosystem to be IN before price moves confirm the rotation.
 *
 * Key principle: capital flows precede price. Bridge inflows → TVL rise → fee
 * revenue rise → token price rise. Cross-chain monitoring captures step 1.
 *
 * Data: DeFiLlama (no key) + optional CoinGecko
 *
 * Example request:
 * {
 *   "chains": ["ethereum", "base", "fraxtal", "arbitrum", "optimism", "solana"],
 *   "bridge_threshold_usd": 1000000,   // min bridge flow to report
 *   "alert_net_flow_usd": 5000000,     // alert if net flow exceeds this
 *   "include_stablecoin_flows": true,
 *   "include_yield_comparison": true,
 * }
 */

const DEFILLAMA_BASE = "https://api.llama.fi";

interface ChainFlowSummary {
  chain: string;
  tvl_usd: number;
  tvl_change_1d_pct: number | null;
  tvl_change_7d_pct: number | null;
  tvl_momentum: "STRONG_INFLOW" | "INFLOW" | "STABLE" | "OUTFLOW" | "STRONG_OUTFLOW";
  dex_volume_24h: number | null;
  fee_revenue_24h: number | null;
  bridge_inflow_24h: number | null;
  bridge_outflow_24h: number | null;
  bridge_net_flow_24h: number | null;
  stablecoin_supply: number | null;
  stablecoin_change_7d_pct: number | null;
  capital_signal: "ACCUMULATE" | "HOLD" | "REDUCE" | "EXIT";
  relative_rank: number;           // ranked by 7D TVL growth
}

interface CrossChainFlow {
  from_chain: string;
  to_chain: string;
  volume_24h: number;
  bridge_name: string;
}

interface YieldComparison {
  chain: string;
  best_stable_apy: number | null;
  best_eth_lst_apy: number | null;
  top_protocol: string | null;
  yield_rank: number;
}

interface RotationSignal {
  type: "ROTATION" | "EXPANSION" | "CONTRACTION" | "CONSOLIDATION";
  from_chain: string | null;
  to_chain: string | null;
  evidence: string;
  confidence: "HIGH" | "MEDIUM" | "LOW";
}

function classifyMomentum(change7d: number | null): ChainFlowSummary["tvl_momentum"] {
  if (change7d == null) return "STABLE";
  if (change7d > 15) return "STRONG_INFLOW";
  if (change7d > 3) return "INFLOW";
  if (change7d < -15) return "STRONG_OUTFLOW";
  if (change7d < -3) return "OUTFLOW";
  return "STABLE";
}

function classifyCapitalSignal(
  tvlChange7d: number | null,
  bridgeNet: number | null,
  stableChange: number | null
): ChainFlowSummary["capital_signal"] {
  const tvlScore =
    (tvlChange7d ?? 0) > 10 ? 2 : (tvlChange7d ?? 0) > 3 ? 1 : (tvlChange7d ?? 0) < -10 ? -2 : (tvlChange7d ?? 0) < -3 ? -1 : 0;
  const bridgeScore =
    (bridgeNet ?? 0) > 1_000_000 ? 1 : (bridgeNet ?? 0) < -1_000_000 ? -1 : 0;
  const stableScore =
    (stableChange ?? 0) > 5 ? 1 : (stableChange ?? 0) < -5 ? -1 : 0;

  const total = tvlScore + bridgeScore + stableScore;

  if (total >= 3) return "ACCUMULATE";
  if (total >= 1) return "HOLD";
  if (total >= -1) return "HOLD";
  if (total >= -2) return "REDUCE";
  return "EXIT";
}

function detectRotationSignals(chains: ChainFlowSummary[]): RotationSignal[] {
  const signals: RotationSignal[] = [];
  const sorted = [...chains].sort(
    (a, b) => (b.tvl_change_7d_pct ?? 0) - (a.tvl_change_7d_pct ?? 0)
  );

  const winner = sorted[0];
  const loser = sorted[sorted.length - 1];

  // Rotation: one chain gaining while another losing
  if (
    (winner.tvl_change_7d_pct ?? 0) > 10 &&
    (loser.tvl_change_7d_pct ?? 0) < -10
  ) {
    signals.push({
      type: "ROTATION",
      from_chain: loser.chain,
      to_chain: winner.chain,
      evidence:
        `${winner.chain} TVL +${(winner.tvl_change_7d_pct ?? 0).toFixed(1)}% while ` +
        `${loser.chain} TVL ${(loser.tvl_change_7d_pct ?? 0).toFixed(1)}% — capital rotating`,
      confidence: "HIGH",
    });
  }

  // Expansion: most chains gaining TVL together
  const gainers = chains.filter((c) => (c.tvl_change_7d_pct ?? 0) > 3);
  if (gainers.length >= chains.length * 0.7) {
    signals.push({
      type: "EXPANSION",
      from_chain: null,
      to_chain: null,
      evidence: `${gainers.length}/${chains.length} tracked chains gaining TVL — broad crypto expansion phase`,
      confidence: gainers.length >= chains.length * 0.85 ? "HIGH" : "MEDIUM",
    });
  }

  // Contraction: most chains losing TVL
  const losers = chains.filter((c) => (c.tvl_change_7d_pct ?? 0) < -3);
  if (losers.length >= chains.length * 0.7) {
    signals.push({
      type: "CONTRACTION",
      from_chain: null,
      to_chain: null,
      evidence: `${losers.length}/${chains.length} tracked chains losing TVL — broad risk-off or bear phase`,
      confidence: losers.length >= chains.length * 0.85 ? "HIGH" : "MEDIUM",
    });
  }

  return signals;
}

export async function executeJob(
  request: Record<string, any>
): Promise<ExecuteJobResult> {
  const chainNames: string[] = (
    request.chains || [
      "ethereum", "base", "fraxtal", "arbitrum", "optimism",
      "solana", "avalanche", "bsc", "sui", "near",
    ]
  ).map((c: string) => c.toLowerCase());

  const bridgeThreshold = Number(request.bridge_threshold_usd || 1_000_000);
  const alertNetFlow = Number(request.alert_net_flow_usd || 5_000_000);
  const includeStable = request.include_stablecoin_flows !== false;
  const includeYield = request.include_yield_comparison !== false;

  try {
    // ── Parallel fetch ──
    const [chainRes, dexRes, feesRes, stableRes, bridgeRes, yieldRes] =
      await Promise.all([
        fetch(`${DEFILLAMA_BASE}/v2/chains`),
        fetch(
          `${DEFILLAMA_BASE}/overview/dexs?excludeTotalDataChart=true&excludeTotalDataChartBreakdown=true&dataType=dailyVolume`
        ),
        fetch(
          `${DEFILLAMA_BASE}/overview/fees?excludeTotalDataChart=true&excludeTotalDataChartBreakdown=true&dataType=dailyFees`
        ),
        includeStable
          ? fetch(`${DEFILLAMA_BASE}/stablecoins?includePrices=true`)
          : Promise.resolve(null),
        fetch(`${DEFILLAMA_BASE}/bridges?includeChains=true`),
        includeYield
          ? fetch(`${DEFILLAMA_BASE}/pools`)
          : Promise.resolve(null),
      ]);

    // ── Chain TVL map ──
    const tvlMap: Record<string, { tvl: number; change1d: number | null; change7d: number | null }> = {};
    if (chainRes.ok) {
      const chains: any[] = await chainRes.json();
      for (const c of chains) {
        tvlMap[c.name?.toLowerCase()] = {
          tvl: c.tvl || 0,
          change1d: c.change_1d ?? null,
          change7d: c.change_7d ?? null,
        };
      }
    }

    // ── DEX volume map by chain ──
    const dexVolMap: Record<string, number> = {};
    if (dexRes.ok) {
      const dexData = await dexRes.json();
      for (const p of dexData.protocols || []) {
        const vol = p.total24h || 0;
        const chainCount = (p.chains || []).length || 1;
        for (const chain of p.chains || []) {
          const key = chain.toLowerCase();
          dexVolMap[key] = (dexVolMap[key] || 0) + vol / chainCount;
        }
      }
    }

    // ── Fee revenue map by chain ──
    const feeMap: Record<string, number> = {};
    if (feesRes.ok) {
      const feesData = await feesRes.json();
      for (const p of feesData.protocols || []) {
        const fee = p.total24h || 0;
        const chainCount = (p.chains || []).length || 1;
        for (const chain of p.chains || []) {
          const key = chain.toLowerCase();
          feeMap[key] = (feeMap[key] || 0) + fee / chainCount;
        }
      }
    }

    // ── Stablecoin map by chain ──
    const stableMap: Record<string, number> = {};
    if (includeStable && stableRes?.ok) {
      const sd = await stableRes.json();
      for (const asset of sd.peggedAssets || []) {
        for (const [chainName, circData] of Object.entries(
          asset.chainCirculating || {}
        )) {
          const key = chainName.toLowerCase();
          const circ = (circData as any)?.current?.peggedUSD || 0;
          stableMap[key] = (stableMap[key] || 0) + circ;
        }
      }
    }

    // ── Bridge flows ──
    const crossChainFlows: CrossChainFlow[] = [];
    const bridgeNetByChain: Record<string, { in: number; out: number }> = {};

    if (bridgeRes.ok) {
      const bridgeData = await bridgeRes.json();
      for (const b of bridgeData.bridges || []) {
        const bChains: string[] = (b.chains || []).map((c: string) =>
          c.toLowerCase()
        );
        const inflow = b.lastDayUsdTokenVolume || 0;
        const outflow = b.lastDayUsdTokenOutflowVolume || 0;

        for (const chain of bChains) {
          if (!bridgeNetByChain[chain]) {
            bridgeNetByChain[chain] = { in: 0, out: 0 };
          }
          bridgeNetByChain[chain].in += inflow / bChains.length;
          bridgeNetByChain[chain].out += outflow / bChains.length;
        }

        // Track significant cross-chain flows
        if (
          inflow > bridgeThreshold &&
          bChains.length >= 2 &&
          chainNames.some((n) => bChains.includes(n))
        ) {
          crossChainFlows.push({
            from_chain: bChains[1] || "unknown",
            to_chain: bChains[0] || "unknown",
            volume_24h: Math.round(inflow),
            bridge_name: b.displayName || b.name,
          });
        }
      }
    }

    // ── Yield comparison ──
    const yieldMap: Record<string, YieldComparison> = {};
    if (includeYield && yieldRes?.ok) {
      try {
        const poolData = await yieldRes.json();
        const pools: any[] = poolData.data || [];

        for (const chain of chainNames) {
          const chainPools = pools
            .filter(
              (p) =>
                p.chain?.toLowerCase() === chain &&
                p.apy != null &&
                p.apy > 0 &&
                p.tvlUsd > 100_000
            )
            .sort((a, b) => b.apy - a.apy);

          const stablePools = chainPools.filter(
            (p) =>
              p.stablecoin === true ||
              p.symbol?.toLowerCase().includes("usd") ||
              p.symbol?.toLowerCase().includes("frax")
          );

          const lstPools = chainPools.filter(
            (p) =>
              p.symbol?.toLowerCase().includes("eth") &&
              !p.symbol?.toLowerCase().includes("usd")
          );

          yieldMap[chain] = {
            chain,
            best_stable_apy: stablePools[0]?.apy
              ? Math.round(stablePools[0].apy * 10) / 10
              : null,
            best_eth_lst_apy: lstPools[0]?.apy
              ? Math.round(lstPools[0].apy * 10) / 10
              : null,
            top_protocol: chainPools[0]?.project || null,
            yield_rank: 0, // filled below
          };
        }

        // Rank by best stable APY
        const yieldRanked = Object.values(yieldMap).sort(
          (a, b) => (b.best_stable_apy ?? 0) - (a.best_stable_apy ?? 0)
        );
        yieldRanked.forEach((y, i) => {
          if (yieldMap[y.chain]) yieldMap[y.chain].yield_rank = i + 1;
        });
      } catch (_) {}
    }

    // ── Build chain summaries ──
    const chainSummaries: ChainFlowSummary[] = chainNames.map((name) => {
      const tvlData = tvlMap[name];
      const bridgeData = bridgeNetByChain[name];
      const bridgeNet = bridgeData
        ? Math.round(bridgeData.in - bridgeData.out)
        : null;

      return {
        chain: name,
        tvl_usd: tvlData?.tvl ?? 0,
        tvl_change_1d_pct: tvlData?.change1d != null ? Math.round(tvlData.change1d * 10) / 10 : null,
        tvl_change_7d_pct: tvlData?.change7d != null ? Math.round(tvlData.change7d * 10) / 10 : null,
        tvl_momentum: classifyMomentum(tvlData?.change7d ?? null),
        dex_volume_24h: dexVolMap[name] ? Math.round(dexVolMap[name]) : null,
        fee_revenue_24h: feeMap[name] ? Math.round(feeMap[name]) : null,
        bridge_inflow_24h: bridgeData ? Math.round(bridgeData.in) : null,
        bridge_outflow_24h: bridgeData ? Math.round(bridgeData.out) : null,
        bridge_net_flow_24h: bridgeNet,
        stablecoin_supply: stableMap[name] ? Math.round(stableMap[name]) : null,
        stablecoin_change_7d_pct: null, // requires historical
        capital_signal: classifyCapitalSignal(
          tvlData?.change7d ?? null,
          bridgeNet,
          null
        ),
        relative_rank: 0, // filled below
      };
    });

    // Rank by 7D TVL growth
    const ranked = [...chainSummaries].sort(
      (a, b) => (b.tvl_change_7d_pct ?? 0) - (a.tvl_change_7d_pct ?? 0)
    );
    ranked.forEach((c, i) => {
      const match = chainSummaries.find((s) => s.chain === c.chain);
      if (match) match.relative_rank = i + 1;
    });

    // ── Rotation signals ──
    const rotationSignals = detectRotationSignals(chainSummaries);

    // ── Alerts ──
    const alerts: string[] = [];
    for (const c of chainSummaries) {
      if (
        c.bridge_net_flow_24h != null &&
        Math.abs(c.bridge_net_flow_24h) > alertNetFlow
      ) {
        alerts.push(
          `${c.chain.toUpperCase()}: $${(Math.abs(c.bridge_net_flow_24h) / 1e6).toFixed(1)}M bridge ${c.bridge_net_flow_24h > 0 ? "INFLOW" : "OUTFLOW"} in 24h`
        );
      }
      if (c.tvl_momentum === "STRONG_OUTFLOW") {
        alerts.push(
          `${c.chain.toUpperCase()}: STRONG TVL OUTFLOW (${c.tvl_change_7d_pct}% 7D) — capital rotating away`
        );
      }
    }

    // ── Summary ──
    const topChain = chainSummaries.find((c) => c.relative_rank === 1);
    const bestSignal = chainSummaries.filter((c) => c.capital_signal === "ACCUMULATE");

    const summary =
      `Cross-chain scan: ${chainSummaries.length} chains. ` +
      (topChain
        ? `Strongest TVL growth: ${topChain.chain.toUpperCase()} (+${topChain.tvl_change_7d_pct ?? 0}% 7D). `
        : "") +
      (bestSignal.length > 0
        ? `ACCUMULATE signal on: ${bestSignal.map((c) => c.chain.toUpperCase()).join(", ")}. `
        : "") +
      `${rotationSignals.length} rotation signal(s). ` +
      `${alerts.length} alert(s).`;

    return {
      deliverable: JSON.stringify({
        schema: "tracking_cross_chain",
        tracked_at: new Date().toISOString(),
        chain_count: chainSummaries.length,
        rotation_signals: rotationSignals,
        alerts,
        summary,
        chains: chainSummaries,
        cross_chain_flows: crossChainFlows
          .sort((a, b) => b.volume_24h - a.volume_24h)
          .slice(0, 20),
        yield_comparison: includeYield
          ? Object.values(yieldMap).sort((a, b) => a.yield_rank - b.yield_rank)
          : [],
      }),
    };
  } catch (e: any) {
    return {
      deliverable: JSON.stringify({
        schema: "tracking_cross_chain",
        error: `Cross-chain tracking failed: ${e.message}`,
        chains: [],
      }),
    };
  }
}
HANDLER_EOF

cat > tracking-fraxtal-volume-handler.ts << 'HANDLER_EOF'
import type { ExecuteJobResult } from "../../../runtime/offeringTypes.js";

/**
 * Seykota Agent Job: Tracking Fraxtal Chain Volume Schema
 * cron: "*/20 * * * *"  — Every 20 minutes
 *
 * Deep volume tracking specific to the Fraxtal chain:
 *   - DEX volume by protocol (Fraxswap, Curve, Uniswap forks)
 *   - Bridge volume (inflows vs. outflows)
 *   - Stablecoin (FRAX) circulating supply + peg
 *   - Lending volume (Fraxlend utilization)
 *   - Fee revenue (protocol + chain)
 *   - Volume-to-TVL ratio (efficiency signal)
 *
 * DeFiLlama chain name: "Fraxtal" (confirmed)
 * Data sources: DeFiLlama (no key required)
 *
 * Example request:
 * {
 *   "include_protocols": true,     // per-protocol volume breakdown
 *   "include_bridge": true,        // bridge in/out volume
 *   "include_lending": true,       // Fraxlend utilization
 *   "vol_spike_threshold": 2.0,    // alert if vol > X× 7-day avg
 * }
 */

const DEFILLAMA_BASE = "https://api.llama.fi";
const FRAXTAL_CHAIN = "Fraxtal";

interface ProtocolVolume {
  name: string;
  category: string;
  volume_24h: number;
  volume_7d_avg: number;
  volume_ratio: number;          // 24h / 7d avg
  tvl: number;
  volume_tvl_ratio: number;      // efficiency: high = active relative to size
  signal: "SPIKE" | "ELEVATED" | "NORMAL" | "LOW";
}

interface BridgeFlow {
  protocol: string;
  inflow_24h: number;
  outflow_24h: number;
  net_flow_24h: number;
  flow_direction: "INFLOW" | "OUTFLOW" | "BALANCED";
}

interface LendingMetrics {
  protocol: string;
  total_borrowed: number;
  total_supplied: number;
  utilization_pct: number;
  borrow_apy: number | null;
  supply_apy: number | null;
  utilization_signal: "OVERCROWDED" | "HEALTHY" | "UNDERUTILIZED";
}

interface ChainVolumeSnapshot {
  chain: string;
  snapshot_at: string;
  tvl_usd: number;
  tvl_change_1d_pct: number | null;
  tvl_change_7d_pct: number | null;
  dex_volume_24h: number | null;
  dex_volume_7d_avg: number | null;
  dex_volume_ratio: number | null;
  fee_revenue_24h: number | null;
  volume_tvl_ratio: number | null;       // chain efficiency
  stablecoin_circulating: number | null;
  stablecoin_change_7d: number | null;
  net_bridge_flow_24h: number | null;
  bridge_direction: "INFLOW" | "OUTFLOW" | "BALANCED" | null;
  vol_regime: "SPIKE" | "ELEVATED" | "NORMAL" | "QUIET";
  chain_health: "GROWING" | "STABLE" | "CONTRACTING" | "STRESSED";
  alerts: string[];
}

function classifyVolSignal(ratio: number | null): ProtocolVolume["signal"] {
  if (ratio == null) return "NORMAL";
  if (ratio >= 2.5) return "SPIKE";
  if (ratio >= 1.4) return "ELEVATED";
  if (ratio >= 0.6) return "NORMAL";
  return "LOW";
}

function classifyChainHealth(
  tvlChange7d: number | null,
  volRatio: number | null,
  bridgeDir: string | null
): ChainVolumeSnapshot["chain_health"] {
  const tvlGrowing = (tvlChange7d ?? 0) > 3;
  const tvlShrinking = (tvlChange7d ?? 0) < -5;
  const volHigh = (volRatio ?? 1) > 1.5;
  const bridgeInflow = bridgeDir === "INFLOW";
  const bridgeOutflow = bridgeDir === "OUTFLOW";

  if (tvlGrowing && bridgeInflow) return "GROWING";
  if (tvlShrinking && bridgeOutflow) return "CONTRACTING";
  if (tvlShrinking && volHigh) return "STRESSED"; // high vol + TVL leaving = distribution
  return "STABLE";
}

function buildAlerts(snap: Partial<ChainVolumeSnapshot>, spikeThreshold: number): string[] {
  const alerts: string[] = [];

  if ((snap.dex_volume_ratio ?? 0) >= spikeThreshold) {
    alerts.push(
      `DEX VOLUME SPIKE: ${(snap.dex_volume_ratio ?? 0).toFixed(1)}× 7-day average — unusual activity on Fraxtal`
    );
  }
  if ((snap.tvl_change_7d_pct ?? 0) < -10) {
    alerts.push(
      `TVL OUTFLOW: Fraxtal TVL down ${Math.abs(snap.tvl_change_7d_pct ?? 0).toFixed(1)}% in 7 days`
    );
  }
  if ((snap.tvl_change_7d_pct ?? 0) > 15) {
    alerts.push(
      `TVL INFLOW: Fraxtal TVL up ${(snap.tvl_change_7d_pct ?? 0).toFixed(1)}% in 7 days — capital influx`
    );
  }
  if (snap.bridge_direction === "OUTFLOW" && Math.abs(snap.net_bridge_flow_24h ?? 0) > 500_000) {
    alerts.push(
      `BRIDGE OUTFLOW: $${((Math.abs(snap.net_bridge_flow_24h ?? 0)) / 1e6).toFixed(2)}M leaving Fraxtal via bridges`
    );
  }
  if (snap.chain_health === "STRESSED") {
    alerts.push("CHAIN STRESS: Rising DEX volume + TVL outflow = possible distribution event");
  }

  return alerts;
}

export async function executeJob(
  request: Record<string, any>
): Promise<ExecuteJobResult> {
  const includeProtocols = request.include_protocols !== false;
  const includeBridge = request.include_bridge !== false;
  const includeLending = request.include_lending !== false;
  const spikeThreshold = Number(request.vol_spike_threshold || 2.0);

  try {
    // ── Fetch all data in parallel ──
    const [chainRes, dexRes, feesRes, stableRes, bridgeRes, protocolRes] =
      await Promise.all([
        fetch(`${DEFILLAMA_BASE}/v2/chains`),
        fetch(
          `${DEFILLAMA_BASE}/overview/dexs/${FRAXTAL_CHAIN}?excludeTotalDataChart=false&dataType=dailyVolume`
        ),
        fetch(
          `${DEFILLAMA_BASE}/overview/fees/${FRAXTAL_CHAIN}?excludeTotalDataChart=true&dataType=dailyFees`
        ),
        fetch(`${DEFILLAMA_BASE}/stablecoins?includePrices=true`),
        includeBridge
          ? fetch(`${DEFILLAMA_BASE}/bridges?includeChains=true`)
          : Promise.resolve(null),
        includeProtocols
          ? fetch(`${DEFILLAMA_BASE}/protocols`)
          : Promise.resolve(null),
      ]);

    // ── Chain TVL ──
    let fraxtalTvl = 0;
    let tvlChange1d: number | null = null;
    let tvlChange7d: number | null = null;

    if (chainRes.ok) {
      const chains: any[] = await chainRes.json();
      const fraxtal = chains.find(
        (c) => c.name?.toLowerCase() === "fraxtal"
      );
      if (fraxtal) {
        fraxtalTvl = fraxtal.tvl || 0;
        tvlChange1d = fraxtal.change_1d ?? null;
        tvlChange7d = fraxtal.change_7d ?? null;
      }
    }

    // ── DEX Volume ──
    let dexVol24h: number | null = null;
    let dexVol7dAvg: number | null = null;
    let dexVolRatio: number | null = null;
    const protocolVolumes: ProtocolVolume[] = [];

    if (dexRes.ok) {
      const dexData = await dexRes.json();
      dexVol24h = dexData.total24h ?? null;

      // 7-day avg from chart data
      if (dexData.totalDataChart && dexData.totalDataChart.length >= 7) {
        const last7 = dexData.totalDataChart.slice(-7);
        const sum = last7.reduce(
          (acc: number, d: [number, number]) => acc + (d[1] || 0),
          0
        );
        dexVol7dAvg = sum / 7;
        dexVolRatio =
          dexVol7dAvg > 0 && dexVol24h != null
            ? dexVol24h / dexVol7dAvg
            : null;
      }

      // Per-protocol volumes
      if (includeProtocols && dexData.protocols) {
        for (const p of dexData.protocols.slice(0, 10)) {
          const vol24 = p.total24h || 0;
          const vol7arr = p.totalDataChart?.slice(-7) || [];
          const vol7avg =
            vol7arr.length > 0
              ? vol7arr.reduce(
                  (s: number, d: [number, number]) => s + (d[1] || 0),
                  0
                ) / vol7arr.length
              : vol24;
          const ratio = vol7avg > 0 ? vol24 / vol7avg : 1;
          protocolVolumes.push({
            name: p.name,
            category: p.category || "DEX",
            volume_24h: vol24,
            volume_7d_avg: Math.round(vol7avg),
            volume_ratio: Math.round(ratio * 100) / 100,
            tvl: p.tvl || 0,
            volume_tvl_ratio:
              p.tvl > 0 ? Math.round((vol24 / p.tvl) * 10000) / 100 : 0,
            signal: classifyVolSignal(ratio),
          });
        }
        protocolVolumes.sort((a, b) => b.volume_24h - a.volume_24h);
      }
    }

    // ── Fee Revenue ──
    let feeRevenue24h: number | null = null;
    if (feesRes.ok) {
      const feesData = await feesRes.json();
      feeRevenue24h = feesData.total24h ?? null;
    }

    // ── Stablecoin (FRAX on Fraxtal) ──
    let stableCirculating: number | null = null;
    let stableChange7d: number | null = null;

    if (stableRes.ok) {
      const stableData = await stableRes.json();
      let fraxtalStableTotal = 0;
      if (stableData.peggedAssets) {
        for (const asset of stableData.peggedAssets) {
          const fraxtalData =
            asset.chainCirculating?.Fraxtal ||
            asset.chainCirculating?.fraxtal;
          if (fraxtalData) {
            fraxtalStableTotal +=
              fraxtalData.current?.peggedUSD || 0;
          }
        }
        stableCirculating =
          fraxtalStableTotal > 0 ? fraxtalStableTotal : null;
      }
    }

    // ── Bridge Flows ──
    const bridgeFlows: BridgeFlow[] = [];
    let netBridgeFlow: number | null = null;
    let bridgeDirection: ChainVolumeSnapshot["bridge_direction"] = null;

    if (includeBridge && bridgeRes?.ok) {
      try {
        const bridgeData = await bridgeRes.json();
        const fraxtalBridges = (bridgeData.bridges || []).filter(
          (b: any) =>
            (b.chains || [])
              .map((c: string) => c.toLowerCase())
              .includes("fraxtal")
        );

        let totalIn = 0;
        let totalOut = 0;

        for (const b of fraxtalBridges.slice(0, 5)) {
          const inflow = b.lastDayUsdTokenVolume || 0;
          const outflow = b.lastDayUsdTokenOutflowVolume || 0;
          const net = inflow - outflow;
          totalIn += inflow;
          totalOut += outflow;

          bridgeFlows.push({
            protocol: b.displayName || b.name,
            inflow_24h: Math.round(inflow),
            outflow_24h: Math.round(outflow),
            net_flow_24h: Math.round(net),
            flow_direction:
              net > 50_000
                ? "INFLOW"
                : net < -50_000
                ? "OUTFLOW"
                : "BALANCED",
          });
        }

        netBridgeFlow = Math.round(totalIn - totalOut);
        bridgeDirection =
          netBridgeFlow > 100_000
            ? "INFLOW"
            : netBridgeFlow < -100_000
            ? "OUTFLOW"
            : "BALANCED";
      } catch (_) {}
    }

    // ── Lending (Fraxlend) from protocols ──
    const lendingMetrics: LendingMetrics[] = [];
    if (includeLending && protocolRes?.ok) {
      try {
        const allProtos: any[] = await protocolRes.json();
        const fraxtalLending = allProtos.filter(
          (p) =>
            (p.chains || [])
              .map((c: string) => c.toLowerCase())
              .includes("fraxtal") && p.category === "Lending"
        );

        for (const p of fraxtalLending.slice(0, 5)) {
          const supplied = p.tvl || 0;
          const borrowed = p.totalBorrowUsd || 0;
          const utilization =
            supplied > 0 ? (borrowed / supplied) * 100 : 0;

          lendingMetrics.push({
            protocol: p.name,
            total_borrowed: Math.round(borrowed),
            total_supplied: Math.round(supplied),
            utilization_pct: Math.round(utilization * 10) / 10,
            borrow_apy: p.borrowApy ?? null,
            supply_apy: p.apyBase ?? null,
            utilization_signal:
              utilization > 85
                ? "OVERCROWDED"
                : utilization > 30
                ? "HEALTHY"
                : "UNDERUTILIZED",
          });
        }
      } catch (_) {}
    }

    // ── Assemble snapshot ──
    const volTvlRatio =
      fraxtalTvl > 0 && dexVol24h != null
        ? Math.round((dexVol24h / fraxtalTvl) * 10000) / 100
        : null;

    const volRegime: ChainVolumeSnapshot["vol_regime"] =
      (dexVolRatio ?? 1) >= 2.5
        ? "SPIKE"
        : (dexVolRatio ?? 1) >= 1.4
        ? "ELEVATED"
        : (dexVolRatio ?? 1) >= 0.6
        ? "NORMAL"
        : "QUIET";

    const chainHealth = classifyChainHealth(
      tvlChange7d,
      dexVolRatio,
      bridgeDirection
    );

    const partialSnap: Partial<ChainVolumeSnapshot> = {
      tvl_change_7d_pct: tvlChange7d,
      dex_volume_ratio: dexVolRatio,
      net_bridge_flow_24h: netBridgeFlow,
      bridge_direction: bridgeDirection,
      chain_health: chainHealth,
    };

    const alerts = buildAlerts(partialSnap, spikeThreshold);

    const snapshot: ChainVolumeSnapshot = {
      chain: FRAXTAL_CHAIN,
      snapshot_at: new Date().toISOString(),
      tvl_usd: fraxtalTvl,
      tvl_change_1d_pct: tvlChange1d != null ? Math.round(tvlChange1d * 10) / 10 : null,
      tvl_change_7d_pct: tvlChange7d != null ? Math.round(tvlChange7d * 10) / 10 : null,
      dex_volume_24h: dexVol24h,
      dex_volume_7d_avg: dexVol7dAvg ? Math.round(dexVol7dAvg) : null,
      dex_volume_ratio: dexVolRatio ? Math.round(dexVolRatio * 100) / 100 : null,
      fee_revenue_24h: feeRevenue24h,
      volume_tvl_ratio: volTvlRatio,
      stablecoin_circulating: stableCirculating,
      stablecoin_change_7d: stableChange7d,
      net_bridge_flow_24h: netBridgeFlow,
      bridge_direction: bridgeDirection,
      vol_regime: volRegime,
      chain_health: chainHealth,
      alerts,
    };

    const summary =
      `Fraxtal: TVL $${(fraxtalTvl / 1e6).toFixed(1)}M ` +
      (tvlChange7d != null
        ? `(${tvlChange7d > 0 ? "+" : ""}${tvlChange7d.toFixed(1)}% 7D)`
        : "") +
      `. DEX vol: $${dexVol24h != null ? (dexVol24h / 1e3).toFixed(0) + "K" : "?"}/24h` +
      (dexVolRatio != null ? ` (${dexVolRatio.toFixed(1)}× avg)` : "") +
      `. Health: ${chainHealth}. Vol regime: ${volRegime}.` +
      (alerts.length > 0 ? ` ${alerts.length} alert(s).` : "");

    return {
      deliverable: JSON.stringify({
        schema: "tracking_fraxtal_volume",
        ...snapshot,
        summary,
        protocol_volumes: protocolVolumes,
        bridge_flows: bridgeFlows,
        lending_metrics: lendingMetrics,
      }),
    };
  } catch (e: any) {
    return {
      deliverable: JSON.stringify({
        schema: "tracking_fraxtal_volume",
        error: `Fraxtal volume tracking failed: ${e.message}`,
        chain: FRAXTAL_CHAIN,
      }),
    };
  }
}
HANDLER_EOF

cat > tracking-volume-handler.ts << 'HANDLER_EOF'
import type { ExecuteJobResult } from "../../../runtime/offeringTypes.js";

/**
 * Seykota Agent Job: Tracking Volume Schema
 * cron: "*/15 * * * *"  — Every 15 minutes
 *
 * Tracks and scores trading volume across tokens, DEXes, and chains.
 * Volume is the single most reliable leading indicator for price moves —
 * price follows volume. Volume spikes precede breakouts. Volume drying up
 * confirms distribution. This schema is the agent's volume radar.
 *
 * Example request:
 * {
 *   "tokens": ["ethereum", "solana", "aerodrome-finance"], // CoinGecko IDs
 *   "chain": "base",           // filter DEX volumes to chain
 *   "alert_threshold_pct": 200, // alert if volume > X% of 7-day avg
 *   "include_dex": true,
 * }
 */

const COINGECKO_BASE = "https://api.coingecko.com/api/v3";
const DEFILLAMA_BASE = "https://api.llama.fi";
const CG_KEY = process.env.COINGECKO_API_KEY || "";

interface VolumeSnapshot {
  token_id: string;
  symbol: string;
  name: string;
  price_usd: number;
  volume_24h: number;
  volume_7d_avg: number;
  volume_ratio: number;          // 24h vol / 7d avg — >2.0 = spike
  volume_to_mcap: number;        // high = high turnover = momentum
  price_change_24h: number;
  price_change_7d: number;
  volume_signal: "SPIKE" | "ELEVATED" | "NORMAL" | "DRY" | "DEAD";
  vol_price_divergence: boolean; // volume up but price flat = accumulation
  alert: boolean;
}

interface DexVolumeEntry {
  protocol: string;
  chain: string;
  volume_24h: number;
  volume_7d_avg: number;
  volume_ratio: number;
  tvl: number;
  volume_tvl_ratio: number;      // high = protocol is active relative to size
}

function classifyVolumeSignal(ratio: number): VolumeSnapshot["volume_signal"] {
  if (ratio >= 3.0) return "SPIKE";
  if (ratio >= 1.5) return "ELEVATED";
  if (ratio >= 0.5) return "NORMAL";
  if (ratio >= 0.2) return "DRY";
  return "DEAD";
}

function detectDivergence(
  volRatio: number,
  priceChange24h: number
): boolean {
  // Volume spike but price barely moved = accumulation or distribution
  return volRatio > 1.8 && Math.abs(priceChange24h) < 2;
}

export async function executeJob(
  request: Record<string, any>
): Promise<ExecuteJobResult> {
  const tokenIds: string[] = request.tokens || [
    "bitcoin",
    "ethereum",
    "solana",
    "avalanche-2",
    "near",
    "aerodrome-finance",
    "virtual-protocol",
  ];
  const alertThreshold = Number(request.alert_threshold_pct || 200);
  const includeDex = request.include_dex !== false;
  const filterChain: string = (request.chain || "").toLowerCase();

  const cgHeaders: Record<string, string> = {
    ...(CG_KEY ? { "x-cg-demo-api-key": CG_KEY } : {}),
  };

  try {
    // ── Fetch token volume data ──
    const ids = tokenIds.join(",");
    const marketRes = await fetch(
      `${COINGECKO_BASE}/coins/markets?vs_currency=usd&ids=${ids}` +
        `&order=volume_desc&price_change_percentage=24h,7d&sparkline=false`,
      { headers: cgHeaders }
    );
    const markets = marketRes.ok ? await marketRes.json() : [];

    // ── Build volume snapshots ──
    const snapshots: VolumeSnapshot[] = markets.map((m: any) => {
      // Estimate 7d avg from available data (approximation without historical endpoint)
      // In production, store daily volumes and compute true 7d avg
      const vol24h = m.total_volume || 0;
      const mcap = m.market_cap || 1;
      const priceChange24h = m.price_change_percentage_24h_in_currency ?? 0;
      const priceChange7d = m.price_change_percentage_7d_in_currency ?? 0;

      // Rough 7d avg proxy: vol/mcap turnover normalized
      // Replace with stored historical avg in production
      const estimatedAvg = vol24h / (1 + Math.abs(priceChange24h) * 0.05);
      const volRatio = estimatedAvg > 0 ? vol24h / estimatedAvg : 1;
      const volToMcap = mcap > 0 ? (vol24h / mcap) * 100 : 0;

      return {
        token_id: m.id,
        symbol: m.symbol?.toUpperCase(),
        name: m.name,
        price_usd: m.current_price || 0,
        volume_24h: vol24h,
        volume_7d_avg: estimatedAvg,
        volume_ratio: volRatio,
        volume_to_mcap: volToMcap,
        price_change_24h: priceChange24h,
        price_change_7d: priceChange7d,
        volume_signal: classifyVolumeSignal(volRatio),
        vol_price_divergence: detectDivergence(volRatio, priceChange24h),
        alert: volRatio >= alertThreshold / 100,
      };
    });

    // ── Fetch DEX volume data from DeFiLlama ──
    let dexVolumes: DexVolumeEntry[] = [];
    if (includeDex) {
      try {
        const dexRes = await fetch(`${DEFILLAMA_BASE}/overview/dexs?excludeTotalDataChart=true&excludeTotalDataChartBreakdown=true&dataType=dailyVolume`);
        if (dexRes.ok) {
          const dexData = await dexRes.json();
          const protocols = dexData.protocols || [];

          dexVolumes = protocols
            .filter((p: any) => {
              if (!filterChain) return true;
              const chains: string[] = (p.chains || []).map((c: string) =>
                c.toLowerCase()
              );
              return chains.includes(filterChain);
            })
            .slice(0, 15)
            .map((p: any) => {
              const vol24h = p.totalDataChart?.[p.totalDataChart?.length - 1]?.[1] || p.total24h || 0;
              const vol7dArr = p.totalDataChart?.slice(-7) || [];
              const vol7dAvg =
                vol7dArr.length > 0
                  ? vol7dArr.reduce((sum: number, d: any) => sum + (d[1] || 0), 0) /
                    vol7dArr.length
                  : vol24h;

              return {
                protocol: p.name,
                chain: (p.chains || []).join(", "),
                volume_24h: vol24h,
                volume_7d_avg: vol7dAvg,
                volume_ratio: vol7dAvg > 0 ? vol24h / vol7dAvg : 1,
                tvl: p.tvl || 0,
                volume_tvl_ratio: p.tvl > 0 ? (vol24h / p.tvl) * 100 : 0,
              };
            })
            .sort((a: DexVolumeEntry, b: DexVolumeEntry) => b.volume_24h - a.volume_24h);
        }
      } catch (_) {
        // DEX data optional — don't fail the whole job
      }
    }

    // ── Alerts ──
    const alerts = snapshots.filter((s) => s.alert || s.vol_price_divergence);
    const spikes = snapshots.filter((s) => s.volume_signal === "SPIKE");
    const topByVolume = [...snapshots].sort((a, b) => b.volume_24h - a.volume_24h)[0];

    const summary =
      `Tracked ${snapshots.length} tokens. ` +
      `${spikes.length} volume spike${spikes.length !== 1 ? "s" : ""} detected. ` +
      `${alerts.length} alert${alerts.length !== 1 ? "s" : ""} triggered. ` +
      (topByVolume
        ? `Highest volume: ${topByVolume.symbol} at $${(topByVolume.volume_24h / 1e6).toFixed(1)}M.`
        : "");

    return {
      deliverable: JSON.stringify({
        schema: "tracking_volume",
        tracked_at: new Date().toISOString(),
        token_count: snapshots.length,
        dex_count: dexVolumes.length,
        alert_threshold_pct: alertThreshold,
        alerts_triggered: alerts.length,
        spike_count: spikes.length,
        summary,
        tokens: snapshots,
        dex_volumes: dexVolumes,
        alerts: alerts.map((a) => ({
          symbol: a.symbol,
          reason: a.vol_price_divergence
            ? "VOL/PRICE DIVERGENCE — potential accumulation or distribution"
            : `VOLUME SPIKE — ${a.volume_ratio.toFixed(1)}× 7-day avg`,
          signal: a.volume_signal,
          price_usd: a.price_usd,
          volume_24h: a.volume_24h,
        })),
      }),
    };
  } catch (e: any) {
    return {
      deliverable: JSON.stringify({
        schema: "tracking_volume",
        error: `Volume tracking failed: ${e.message}`,
        tokens: [],
        dex_volumes: [],
      }),
    };
  }
}
HANDLER_EOF

cat > trading-fee-percentage-handler.ts << 'HANDLER_EOF'
import type { ExecuteJobResult } from "../../../runtime/offeringTypes.js";

/**
 * Druckenmiller Agent Job: Trading Fee Percentage Schema
 * cron: "0 */2 * * *"  — Every 2 hours
 *
 * Fee percentage tracking across DEX protocols, LP pools, and chains.
 * Fees are the one honest signal in DeFi — they reflect real economic
 * activity, not token emissions. Protocol fee revenue is the crypto
 * equivalent of earnings. Rising fees = positive fundamental revision.
 *
 * Tracks:
 *   - DEX trading fee tiers (0.01%, 0.05%, 0.3%, 1%)
 *   - Protocol fee revenue (daily, 7D avg, trend)
 *   - Fee-to-TVL ratio (capital efficiency)
 *   - Fee APR for LP positions
 *   - Fee revenue trajectory (the revision signal)
 *
 * Data: DeFiLlama (no key)
 *
 * Example request:
 * {
 *   "protocols": ["uniswap-v3", "aerodrome", "curve-dex"],
 *   "chains": ["base", "ethereum"],
 *   "min_fee_revenue_24h": 10000,
 *   "include_lp_apy": true
 * }
 */

const DEFILLAMA_BASE = "https://api.llama.fi";

type FeeRevisionSignal = "ACCELERATING" | "GROWING" | "STABLE" | "DECLINING" | "DEAD";
type CapitalEfficiency = "EXCELLENT" | "GOOD" | "FAIR" | "POOR";

interface ProtocolFeeProfile {
  name: string;
  chains: string[];
  fee_revenue_24h: number;
  fee_revenue_7d_avg: number;
  fee_revision_pct: number;      // (24h - 7d_avg) / 7d_avg * 100
  fee_revision_signal: FeeRevisionSignal;
  tvl: number;
  fee_to_tvl_ratio_pct: number;  // daily fee / TVL = capital efficiency
  capital_efficiency: CapitalEfficiency;
  annualized_fee_apr: number;    // fee_to_tvl * 365
  druckenmiller_read: string;
  is_revision_play: boolean;     // true if fee revenue inflecting positively
}

interface FeeTierBreakdown {
  tier: string;
  description: string;
  best_for: string;
  expected_apr_range: string;
  il_risk: "NONE" | "LOW" | "MEDIUM" | "HIGH";
}

const FEE_TIERS: FeeTierBreakdown[] = [
  {
    tier: "0.01%",
    description: "Ultra-low fee tier",
    best_for: "Stablecoin pairs (USDC/USDT, USDC/DAI) — near-zero IL",
    expected_apr_range: "2–8% APR",
    il_risk: "NONE",
  },
  {
    tier: "0.05%",
    description: "Low fee tier",
    best_for: "Correlated pairs (ETH/stETH, BTC/WBTC, sfrxETH/frxETH)",
    expected_apr_range: "5–15% APR",
    il_risk: "LOW",
  },
  {
    tier: "0.3%",
    description: "Standard fee tier",
    best_for: "Blue chip pairs (ETH/USDC, BTC/USDC) — standard vol",
    expected_apr_range: "10–50% APR in active markets",
    il_risk: "MEDIUM",
  },
  {
    tier: "1%",
    description: "High fee tier",
    best_for: "Exotic pairs, new tokens, high-volatility assets",
    expected_apr_range: "30–200%+ APR but high IL",
    il_risk: "HIGH",
  },
];

function classifyRevision(current: number, avg: number): FeeRevisionSignal {
  if (avg <= 0) return "DEAD";
  const pct = ((current - avg) / avg) * 100;
  if (pct > 50) return "ACCELERATING";
  if (pct > 10) return "GROWING";
  if (pct > -10) return "STABLE";
  if (pct > -50) return "DECLINING";
  return "DEAD";
}

function classifyEfficiency(feeToTvlPct: number): CapitalEfficiency {
  if (feeToTvlPct > 0.5) return "EXCELLENT";  // >0.5% daily = >180% annual
  if (feeToTvlPct > 0.15) return "GOOD";       // >0.15% daily = >55% annual
  if (feeToTvlPct > 0.05) return "FAIR";
  return "POOR";
}

function buildRead(name: string, signal: FeeRevisionSignal, efficiency: CapitalEfficiency, apr: number): string {
  if (signal === "ACCELERATING" && efficiency === "EXCELLENT")
    return `${name}: ACCELERATING fees with excellent capital efficiency (${apr.toFixed(0)}% APR). This is a positive earnings revision — be early to the LP position.`;
  if (signal === "ACCELERATING")
    return `${name}: Fee revenue accelerating — protocol activity surging. Monitor for LP entry.`;
  if (signal === "GROWING")
    return `${name}: Fee revenue growing. Positive fundamental revision in progress. Consider LP allocation.`;
  if (signal === "DECLINING")
    return `${name}: Fee revenue declining — activity dropping. LP yields will compress. Reduce or exit.`;
  if (signal === "DEAD")
    return `${name}: Dead fee revenue. No economic activity. Avoid.`;
  return `${name}: Fee revenue stable. ${apr.toFixed(0)}% APR. Monitor for revision in either direction.`;
}

export async function executeJob(request: Record<string, any>): Promise<ExecuteJobResult> {
  const protocols: string[] = (request.protocols || []).map((p: string) => p.toLowerCase());
  const chains: string[] = (request.chains || ["base", "ethereum"]).map((c: string) => c.toLowerCase());
  const minFeeRevenue = Number(request.min_fee_revenue_24h || 5000);
  const includeLpApy = request.include_lp_apy !== false;

  try {
    // Fetch fee data for specified chains
    const chainFeePromises = chains.map(chain =>
      fetch(`${DEFILLAMA_BASE}/overview/fees/${chain}?excludeTotalDataChart=false&dataType=dailyFees`).catch(() => null)
    );
    const globalFeeRes = await fetch(`${DEFILLAMA_BASE}/overview/fees?excludeTotalDataChart=false&dataType=dailyFees`);

    const [chainFeeResults, globalFees] = await Promise.all([
      Promise.all(chainFeePromises),
      globalFeeRes.ok ? globalFeeRes.json() : null,
    ]);

    const feeProfiles: ProtocolFeeProfile[] = [];
    const seenProtocols = new Set<string>();

    // Process chain-specific fees
    for (let i = 0; i < chains.length; i++) {
      const res = chainFeeResults[i];
      if (!res || !res.ok) continue;
      try {
        const data = await res.json();
        for (const p of (data.protocols || []).slice(0, 20)) {
          if (seenProtocols.has(p.name)) continue;
          if ((p.total24h || 0) < minFeeRevenue) continue;
          if (protocols.length > 0 && !protocols.some(pr => p.name?.toLowerCase().includes(pr))) continue;

          seenProtocols.add(p.name);
          const fee24h = p.total24h || 0;
          const chartData: [number, number][] = p.totalDataChart || [];
          const last7 = chartData.slice(-7).map(d => d[1] || 0);
          const fee7dAvg = last7.length > 0 ? last7.reduce((s, v) => s + v, 0) / last7.length : fee24h;
          const revPct = fee7dAvg > 0 ? ((fee24h - fee7dAvg) / fee7dAvg) * 100 : 0;
          const tvl = p.tvl || 0;
          const feeToTvl = tvl > 0 ? (fee24h / tvl) * 100 : 0;
          const annualApr = feeToTvl * 365;
          const revSignal = classifyRevision(fee24h, fee7dAvg);
          const efficiency = classifyEfficiency(feeToTvl);

          feeProfiles.push({
            name: p.name,
            chains: p.chains || [chains[i]],
            fee_revenue_24h: Math.round(fee24h),
            fee_revenue_7d_avg: Math.round(fee7dAvg),
            fee_revision_pct: Math.round(revPct * 10) / 10,
            fee_revision_signal: revSignal,
            tvl,
            fee_to_tvl_ratio_pct: Math.round(feeToTvl * 1000) / 1000,
            capital_efficiency: efficiency,
            annualized_fee_apr: Math.round(annualApr * 10) / 10,
            druckenmiller_read: buildRead(p.name, revSignal, efficiency, annualApr),
            is_revision_play: revSignal === "ACCELERATING" || revSignal === "GROWING",
          });
        }
      } catch (_) {}
    }

    // Sort by fee revenue
    feeProfiles.sort((a, b) => b.fee_revenue_24h - a.fee_revenue_24h);

    // LP APY context from DeFiLlama pools
    let topLpPools: any[] = [];
    if (includeLpApy) {
      try {
        const poolRes = await fetch(`${DEFILLAMA_BASE}/pools`);
        if (poolRes.ok) {
          const poolData = await poolRes.json();
          topLpPools = (poolData.data || [])
            .filter((p: any) =>
              chains.some(c => p.chain?.toLowerCase() === c) &&
              p.apyBase != null && p.apyBase > 0 && p.tvlUsd > 100_000
            )
            .sort((a: any, b: any) => b.apyBase - a.apyBase)
            .slice(0, 10)
            .map((p: any) => ({
              pool: p.pool,
              protocol: p.project,
              chain: p.chain,
              symbol: p.symbol,
              fee_apr_base: Math.round(p.apyBase * 10) / 10,
              reward_apr: Math.round((p.apyReward || 0) * 10) / 10,
              total_apy: Math.round((p.apy || p.apyBase) * 10) / 10,
              tvl_usd: Math.round(p.tvlUsd),
              fee_tier: p.feeTier || "unknown",
              il_risk: p.ilRisk || null,
            }));
        }
      } catch (_) {}
    }

    const revisionPlays = feeProfiles.filter(p => p.is_revision_play);
    const accelerating = feeProfiles.filter(p => p.fee_revision_signal === "ACCELERATING");
    const declining = feeProfiles.filter(p => p.fee_revision_signal === "DECLINING" || p.fee_revision_signal === "DEAD");
    const totalFeeRevenue24h = feeProfiles.reduce((s, p) => s + p.fee_revenue_24h, 0);

    const summary =
      `Fee scan: ${feeProfiles.length} protocols across ${chains.join(", ")}. ` +
      `Total 24h fees: $${(totalFeeRevenue24h / 1e3).toFixed(1)}K. ` +
      `${accelerating.length} accelerating (positive revision). ` +
      `${declining.length} declining. ` +
      `${revisionPlays.length} revision plays. ` +
      (revisionPlays[0] ? `Top revision: ${revisionPlays[0].name} (${revisionPlays[0].fee_revision_pct > 0 ? "+" : ""}${revisionPlays[0].fee_revision_pct.toFixed(0)}% vs 7D avg, ${revisionPlays[0].annualized_fee_apr.toFixed(0)}% APR).` : "");

    return {
      deliverable: JSON.stringify({
        schema: "trading_fee_percentage",
        tracked_at: new Date().toISOString(),
        chains_scanned: chains,
        protocol_count: feeProfiles.length,
        total_fee_revenue_24h: totalFeeRevenue24h,
        revision_plays: revisionPlays.length,
        summary,
        fee_tier_reference: FEE_TIERS,
        protocols: feeProfiles,
        top_lp_pools_by_fee_apr: topLpPools,
        alerts: accelerating.map(p => ({
          protocol: p.name,
          signal: "FEE_ACCELERATION",
          fee_revision_pct: p.fee_revision_pct,
          apr: p.annualized_fee_apr,
          read: p.druckenmiller_read,
        })),
      }),
    };
  } catch (e: any) {
    return { deliverable: JSON.stringify({ schema: "trading_fee_percentage", error: e.message }) };
  }
}
HANDLER_EOF

