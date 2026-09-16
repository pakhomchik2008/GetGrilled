import type { VercelRequest, VercelResponse } from "@vercel/node";
import { verifyAuth } from "../../lib/auth.js";
import { actionMessageContent, buildRoundPrompt } from "../../lib/roundPrompts.js";
import { appendRoundTranscript, getRound } from "../../lib/rounds.js";
import { getSession } from "../../lib/sessions.js";
import { startSSE, streamAssistantText, writeDone } from "../../lib/sse.js";
import { toLLMMessages, nowIso } from "../../lib/transcript.js";

const VALID_ACTIONS = new Set(["hint", "repeat"]);

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

  const { sessionId, roundId, content, action } = req.body ?? {};
  if (typeof sessionId !== "string" || typeof roundId !== "string") {
    res.status(400).json({ error: "sessionId and roundId are required" });
    return;
  }
  if (action !== undefined && !VALID_ACTIONS.has(action)) {
    res.status(400).json({ error: "action must be one of hint, repeat" });
    return;
  }
  const candidateText = action ? actionMessageContent(action) : content;
  if (typeof candidateText !== "string" || candidateText.trim().length === 0) {
    res.status(400).json({ error: "content or a valid action is required" });
    return;
  }

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
    res.status(409).json({ error: `Round is not accepting messages (status: ${round.status})` });
    return;
  }
  if (!session.role_title || !session.seniority) {
    res.status(409).json({ error: "Session is missing personalization data" });
    return;
  }

  const candidateMessage = { role: "candidate" as const, content: candidateText, timestamp: nowIso() };
  await appendRoundTranscript(roundId, round.transcript, candidateMessage);
  const transcriptSoFar = [...round.transcript, candidateMessage];

  const system = buildRoundPrompt(round.round_type, {
    roleTitle: session.role_title,
    seniority: session.seniority,
    focusNotes: session.focus_notes
  });

  startSSE(res);
  try {
    const replyText = await streamAssistantText(res, system, toLLMMessages(transcriptSoFar));
    await appendRoundTranscript(roundId, transcriptSoFar, {
      role: "interviewer",
      content: replyText,
      timestamp: nowIso()
    });
    writeDone(res, sessionId, { roundId });
  } catch (error) {
    res.write(`data: ${JSON.stringify({ type: "error", message: "Interviewer is unavailable right now." })}\n\n`);
    res.end();
    console.error("round/message failed", error);
  }
}
