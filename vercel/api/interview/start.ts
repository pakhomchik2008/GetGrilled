import type { VercelRequest, VercelResponse } from "@vercel/node";
import { verifyAuth } from "../../lib/auth.js";
import { buildSystemPrompt } from "../../lib/anthropic.js";
import { appendTranscriptMessage, createSession, ensureUserRow, logEvent, setQuestionText, setStatus } from "../../lib/sessions.js";
import { startSSE, streamAssistantText, writeDone } from "../../lib/sse.js";
import { assertTransition } from "../../lib/statusMachine.js";
import { isDifficulty } from "../../lib/types.js";
import { nowIso } from "../../lib/transcript.js";

export default async function handler(req: VercelRequest, res: VercelResponse): Promise<void> {
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  let userId: string;
  let email: string | null;
  try {
    ({ userId, email } = await verifyAuth(req));
  } catch {
    res.status(401).json({ error: "Unauthorized" });
    return;
  }

  const { difficulty } = req.body ?? {};
  if (!isDifficulty(difficulty)) {
    res.status(400).json({ error: "difficulty must be one of easy, medium, hard" });
    return;
  }

  await ensureUserRow(userId, email);
  const sessionId = await createSession(userId, difficulty);

  startSSE(res);
  try {
    const questionText = await streamAssistantText(res, buildSystemPrompt(difficulty), [
      { role: "user", content: "Begin the interview by presenting the problem." }
    ]);

    assertTransition("started", "in_progress");
    await setQuestionText(sessionId, questionText);
    await appendTranscriptMessage(sessionId, [], { role: "interviewer", content: questionText, timestamp: nowIso() });
    await setStatus(sessionId, "in_progress");
    await logEvent(userId, sessionId, "session_started");

    writeDone(res, sessionId);
  } catch (error) {
    res.write(`data: ${JSON.stringify({ type: "error", message: "Interviewer is unavailable right now." })}\n\n`);
    res.end();
    console.error("interview/start failed", error);
  }
}
