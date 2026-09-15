import type { VercelRequest, VercelResponse } from "@vercel/node";
import { verifyAuth } from "../../lib/auth.js";
import { buildSystemPrompt } from "../../lib/anthropic.js";
import { appendTranscriptMessage, getSession } from "../../lib/sessions.js";
import { startSSE, streamAssistantText, writeDone } from "../../lib/sse.js";
import { toClaudeMessages, nowIso } from "../../lib/transcript.js";

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

  const { sessionId, content } = req.body ?? {};
  if (typeof sessionId !== "string" || typeof content !== "string" || content.trim().length === 0) {
    res.status(400).json({ error: "sessionId and content are required" });
    return;
  }

  const session = await getSession(sessionId);
  if (!session || session.user_id !== userId) {
    res.status(404).json({ error: "Session not found" });
    return;
  }
  if (session.status !== "in_progress") {
    res.status(409).json({ error: `Session is not accepting messages (status: ${session.status})` });
    return;
  }

  const candidateMessage = { role: "candidate" as const, content, timestamp: nowIso() };
  await appendTranscriptMessage(sessionId, session.transcript, candidateMessage);
  const transcriptSoFar = [...session.transcript, candidateMessage];

  startSSE(res);
  try {
    const replyText = await streamAssistantText(
      res,
      buildSystemPrompt(session.difficulty),
      toClaudeMessages(transcriptSoFar)
    );

    await appendTranscriptMessage(sessionId, transcriptSoFar, {
      role: "interviewer",
      content: replyText,
      timestamp: nowIso()
    });

    writeDone(res, sessionId);
  } catch (error) {
    res.write(`data: ${JSON.stringify({ type: "error", message: "Interviewer is unavailable right now." })}\n\n`);
    res.end();
    console.error("interview/message failed", error);
  }
}
