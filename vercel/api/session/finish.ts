import type { VercelRequest, VercelResponse } from "@vercel/node";
import { verifyAuth } from "../../lib/auth.js";
import { SESSION_SUMMARY_TOOL, buildSessionSummaryPrompt } from "../../lib/roundPrompts.js";
import { parseSessionSummary, FeedbackParseError } from "../../lib/feedbackSchema.js";
import { callTool } from "../../lib/llmClient.js";
import { listRounds } from "../../lib/rounds.js";
import { markStageCompleted } from "../../lib/plans.js";
import { getSession, logEvent, setStatus } from "../../lib/sessions.js";
import { nowIso } from "../../lib/transcript.js";

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

  const { sessionId } = req.body ?? {};
  if (typeof sessionId !== "string") {
    res.status(400).json({ error: "sessionId is required" });
    return;
  }

  const session = await getSession(sessionId);
  if (!session || session.user_id !== userId) {
    res.status(404).json({ error: "Session not found" });
    return;
  }
  if (!session.role_title || !session.seniority) {
    res.status(409).json({ error: "Session is missing personalization data" });
    return;
  }

  const rounds = await listRounds(sessionId);
  const unfinished = rounds.find((round) => round.status === "pending" || round.status === "in_progress");
  if (unfinished) {
    res.status(409).json({ error: `Round ${unfinished.round_type} is not finished yet` });
    return;
  }

  const scoredRounds = rounds.filter((round) => round.status === "completed");
  const system = buildSessionSummaryPrompt({
    roleTitle: session.role_title,
    seniority: session.seniority,
    focusNotes: session.focus_notes,
    jobContext: session.job_context
  });
  const roundsBrief = scoredRounds
    .map(
      (round) =>
        `Round: ${round.round_type}\nFeedback status: ${round.feedback_status}\nFeedback notes: ${round.feedback_notes}`
    )
    .join("\n\n");

  try {
    let overallSummary: string;
    if (scoredRounds.length === 0) {
      overallSummary = "All rounds were skipped — nothing to evaluate this time.";
    } else {
      const raw = await callTool(system, [{ role: "user", content: roundsBrief }], SESSION_SUMMARY_TOOL);
      overallSummary = parseSessionSummary(raw);
    }

    const completedAt = nowIso();
    await setStatus(sessionId, "completed", completedAt);
    if (session.plan_stage_id) {
      await markStageCompleted(session.plan_stage_id, sessionId);
    }
    await logEvent(userId, sessionId, "session_completed");

    res.status(200).json({
      overallSummary,
      rounds: rounds.map((round) => ({
        type: round.round_type,
        status: round.status,
        selfEval: round.self_eval,
        feedbackStatus: round.feedback_status,
        feedbackNotes: round.feedback_notes
      }))
    });
  } catch (error) {
    if (error instanceof FeedbackParseError) {
      console.error("session/finish: malformed summary from model", error);
    } else {
      console.error("session/finish failed", error);
    }
    res.status(502).json({ error: "Couldn't generate the session summary, please try again." });
  }
}
