import type { VercelRequest, VercelResponse } from "@vercel/node";
import { verifyAuth } from "../../lib/auth.js";
import { buildRoundPrompt, roundOpenerMessage } from "../../lib/roundPrompts.js";
import { appendRoundTranscript, getRound } from "../../lib/rounds.js";
import { checkWeeklyLimit, getSession } from "../../lib/sessions.js";
import { startSSE, streamAssistantText, writeDone } from "../../lib/sse.js";
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

  const { sessionId, roundId } = req.body ?? {};
  if (typeof sessionId !== "string" || typeof roundId !== "string") {
    res.status(400).json({ error: "sessionId and roundId are required" });
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
    res.status(409).json({ error: `Round is not ready to start (status: ${round.status})` });
    return;
  }
  if (round.transcript.length > 0) {
    res.status(409).json({ error: "Round already started" });
    return;
  }
  if (!session.role_title || !session.seniority) {
    res.status(409).json({ error: "Session is missing personalization data" });
    return;
  }

  if (round.round_order === 0 && session.mode) {
    const { allowed, limit } = await checkWeeklyLimit(userId, session.mode, sessionId);
    if (!allowed) {
      res.status(403).json({ error: `Weekly free limit reached (${limit}/week for ${session.mode} mode). Upgrade for unlimited sessions.` });
      return;
    }
  }

  const system = buildRoundPrompt(round.round_type, {
    roleTitle: session.role_title,
    seniority: session.seniority,
    focusNotes: session.focus_notes,
    jobContext: session.job_context
  });

  startSSE(res);
  try {
    const openingText = await streamAssistantText(res, system, [
      { role: "user", content: roundOpenerMessage(round.round_type) }
    ]);
    await appendRoundTranscript(roundId, [], { role: "interviewer", content: openingText, timestamp: nowIso() });
    writeDone(res, sessionId, { roundId });
  } catch (error) {
    res.write(`data: ${JSON.stringify({ type: "error", message: "Interviewer is unavailable right now." })}\n\n`);
    res.end();
    console.error("round/start failed", error);
  }
}
