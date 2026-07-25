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
