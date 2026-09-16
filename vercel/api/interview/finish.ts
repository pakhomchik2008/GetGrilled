import type { VercelRequest, VercelResponse } from "@vercel/node";
import { verifyAuth } from "../../lib/auth.js";
import { FEEDBACK_TOOL, buildSystemPrompt } from "../../lib/anthropic.js";
import { parseFeedbackToolInput, FeedbackParseError } from "../../lib/feedbackSchema.js";
import { callTool } from "../../lib/llmClient.js";
import { getSession, logEvent, saveFeedback, setStatus } from "../../lib/sessions.js";
import { assertTransition, InvalidTransitionError } from "../../lib/statusMachine.js";
import { toLLMMessages, nowIso } from "../../lib/transcript.js";
import type { LLMMessage } from "../../lib/providers/types.js";

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

  try {
    assertTransition(session.status, "awaiting_feedback");
  } catch (error) {
    if (error instanceof InvalidTransitionError) {
      res.status(409).json({ error: error.message });
      return;
    }
    throw error;
  }
  await setStatus(sessionId, "awaiting_feedback");

  const messages: LLMMessage[] = [
    ...toLLMMessages(session.transcript),
    { role: "user", content: "I'm done. Please evaluate my performance now." }
  ];

  try {
    const rawFeedback = await callTool(buildSystemPrompt(session.difficulty), messages, FEEDBACK_TOOL);
    const feedback = parseFeedbackToolInput(rawFeedback);
    await saveFeedback(sessionId, feedback);
    assertTransition("awaiting_feedback", "completed");
    await setStatus(sessionId, "completed", nowIso());
    await logEvent(userId, sessionId, "session_completed");

    res.status(200).json(feedback);
  } catch (error) {
    assertTransition("awaiting_feedback", "in_progress");
    await setStatus(sessionId, "in_progress");
    if (error instanceof FeedbackParseError) {
      console.error("interview/finish: malformed feedback from model", error);
      res.status(502).json({ error: "Couldn't generate feedback, please try finishing again." });
      return;
    }
    console.error("interview/finish failed", error);
    res.status(502).json({ error: "Couldn't generate feedback, please try finishing again." });
  }
}
