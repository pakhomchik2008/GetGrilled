import type { VercelRequest, VercelResponse } from "@vercel/node";
import { verifyAuth } from "../../lib/auth.js";
import { ROUND_FEEDBACK_TOOL, buildRoundPrompt } from "../../lib/roundPrompts.js";
import { parseRoundFeedback, FeedbackParseError } from "../../lib/feedbackSchema.js";
import { callTool } from "../../lib/llmClient.js";
import {
  activateNextRound,
  getRound,
  markRoundSkipped,
  saveRoundFeedback
} from "../../lib/rounds.js";
import { getSession } from "../../lib/sessions.js";
import { toLLMMessages, nowIso } from "../../lib/transcript.js";
import type { SelfEval } from "../../lib/types.js";

const VALID_SELF_EVAL = new Set(["rough", "ok", "strong"]);

export default async function handler(req: VercelRequest, res: VercelResponse): Promise<void> {
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  let userId: string;
  try {
    ({ userId } = await verifyAuth(req));
  } catch {
    res.status(401).json({ error: "Unauthorized" });
    return;
  }

  const { sessionId, roundId, selfEval, skip } = req.body ?? {};
  if (typeof sessionId !== "string" || typeof roundId !== "string") {
    res.status(400).json({ error: "sessionId and roundId are required" });
    return;
  }
  if (selfEval !== undefined && selfEval !== null && !VALID_SELF_EVAL.has(selfEval)) {
    res.status(400).json({ error: "selfEval must be one of rough, ok, strong" });
    return;
  }
  const normalizedSelfEval: SelfEval | null = selfEval ?? null;

  const session = await getSession(sessionId);
  if (!session || session.user_id !== userId) {
    res.status(404).json({ error: "Session not found" });
    return;
  }
  const round = await getRound(roundId);
  if (!round || round.session_id !== sessionId) {
    res.status(404).json({ error: "Round not found" });
    return;
  }
  if (round.status !== "in_progress") {
    res.status(409).json({ error: `Round cannot be finished (status: ${round.status})` });
    return;
  }

  const completedAt = nowIso();

  if (skip === true) {
    await markRoundSkipped(roundId, normalizedSelfEval, completedAt);
    const next = await activateNextRound(sessionId, round.round_order, completedAt);
    res.status(200).json({
      round: { id: roundId, status: "skipped" },
      nextRound: next ? { id: next.id, type: next.round_type, order: next.round_order } : null
    });
    return;
  }

  if (round.transcript.length === 0 || !session.role_title || !session.seniority) {
    res.status(409).json({ error: "Round has no content to evaluate" });
    return;
  }

  const system = buildRoundPrompt(round.round_type, {
    roleTitle: session.role_title,
    seniority: session.seniority,
    focusNotes: session.focus_notes
  });
  const messages = [
    ...toLLMMessages(round.transcript),
    { role: "user" as const, content: "I'm done with this round. Please evaluate my performance now." }
  ];

  try {
    const raw = await callTool(system, messages, ROUND_FEEDBACK_TOOL);
    const feedback = parseRoundFeedback(raw);
    await saveRoundFeedback(roundId, feedback, normalizedSelfEval, completedAt);
    const next = await activateNextRound(sessionId, round.round_order, completedAt);

    res.status(200).json({
      round: { id: roundId, status: "completed", feedback, selfEval: normalizedSelfEval },
      nextRound: next ? { id: next.id, type: next.round_type, order: next.round_order } : null
    });
  } catch (error) {
    if (error instanceof FeedbackParseError) {
      console.error("round/finish: malformed feedback from model", error);
    } else {
      console.error("round/finish failed", error);
    }
    res.status(502).json({ error: "Couldn't generate feedback for this round, please try again." });
  }
}
