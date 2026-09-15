import type { VercelRequest, VercelResponse } from "@vercel/node";
import { verifyAuth } from "../../lib/auth.js";
import { FEEDBACK_TOOL, MAX_TOKENS, MODEL, anthropic, buildSystemPrompt } from "../../lib/anthropic.js";
import { parseFeedbackToolInput, FeedbackParseError } from "../../lib/feedbackSchema.js";
import { getSession, logEvent, saveFeedback, setStatus } from "../../lib/sessions.js";
import { assertTransition, InvalidTransitionError } from "../../lib/statusMachine.js";
import { toClaudeMessages, nowIso } from "../../lib/transcript.js";
import type Anthropic from "@anthropic-ai/sdk";

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

  const messages: Anthropic.MessageParam[] = [
    ...toClaudeMessages(session.transcript),
    { role: "user", content: "I'm done. Please evaluate my performance now." }
  ];

  try {
    const response = await anthropic.messages.create({
      model: MODEL,
      max_tokens: MAX_TOKENS,
      system: buildSystemPrompt(session.difficulty),
      messages,
      tools: [FEEDBACK_TOOL],
      tool_choice: { type: "tool", name: "submit_feedback" }
    });

    const toolUse = response.content.find(
      (block): block is Anthropic.ToolUseBlock => block.type === "tool_use" && block.name === "submit_feedback"
    );
    if (!toolUse) {
      throw new Error("Model did not return a submit_feedback tool call");
    }

    const feedback = parseFeedbackToolInput(toolUse.input);
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
