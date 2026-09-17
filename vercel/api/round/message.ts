import type { VercelRequest, VercelResponse } from "@vercel/node";
import { verifyAuth } from "../../lib/auth.js";
import { actionMessageContent, buildRoundPrompt, buildRoundReadinessSystem, ROUND_READY_TOOL } from "../../lib/roundPrompts.js";
import { appendRoundTranscript, getRound } from "../../lib/rounds.js";
import { callTool } from "../../lib/llmClient.js";
import { getSession } from "../../lib/sessions.js";
import { startSSE, streamAssistantText, writeDone } from "../../lib/sse.js";
import { toLLMMessages, nowIso } from "../../lib/transcript.js";
import { isImageMediaType, type TranscriptMessage } from "../../lib/types.js";

const VALID_ACTIONS = new Set(["hint", "repeat"]);
// Base64 length, not raw bytes — comfortably covers a resized screenshot without letting
// someone stuff an oversized payload into the sessions JSONB column.
const MAX_IMAGE_BASE64_LENGTH = 4_000_000;

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

  const { sessionId, roundId, content, action, imageBase64, imageMediaType } = req.body ?? {};
  if (typeof sessionId !== "string" || typeof roundId !== "string") {
    res.status(400).json({ error: "sessionId and roundId are required" });
    return;
  }
  if (action !== undefined && !VALID_ACTIONS.has(action)) {
    res.status(400).json({ error: "action must be one of hint, repeat" });
    return;
  }
  const hasImage = imageBase64 !== undefined;
  if (hasImage) {
    if (typeof imageBase64 !== "string" || imageBase64.length === 0 || imageBase64.length > MAX_IMAGE_BASE64_LENGTH) {
      res.status(400).json({ error: "imageBase64 must be a non-empty base64 string within the size limit" });
      return;
    }
    if (!isImageMediaType(imageMediaType)) {
      res.status(400).json({ error: "imageMediaType must be image/jpeg or image/png" });
      return;
    }
  }
  const candidateText = action ? actionMessageContent(action) : typeof content === "string" ? content : "";
  if (!action && candidateText.trim().length === 0 && !hasImage) {
    res.status(400).json({ error: "content, an image, or a valid action is required" });
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

  const candidateMessage: TranscriptMessage = {
    role: "candidate",
    content: candidateText,
    timestamp: nowIso(),
    ...(hasImage ? { image: { mediaType: imageMediaType, base64: imageBase64 } } : {})
  };
  await appendRoundTranscript(roundId, round.transcript, candidateMessage);
  const transcriptSoFar = [...round.transcript, candidateMessage];

  const system = buildRoundPrompt(round.round_type, {
    roleTitle: session.role_title,
    seniority: session.seniority,
    focusNotes: session.focus_notes,
    jobContext: session.job_context
  });

  startSSE(res);
  try {
    const replyText = await streamAssistantText(res, system, toLLMMessages(transcriptSoFar));
    const transcriptWithReply = [...transcriptSoFar, { role: "interviewer" as const, content: replyText, timestamp: nowIso() }];
    await appendRoundTranscript(roundId, transcriptSoFar, {
      role: "interviewer",
      content: replyText,
      timestamp: nowIso()
    });
    const roundReady = await assessRoundReady(transcriptWithReply);
    writeDone(res, sessionId, { roundId, roundReady });
  } catch (error) {
    res.write(`data: ${JSON.stringify({ type: "error", message: "Interviewer is unavailable right now." })}\n\n`);
    res.end();
    console.error("round/message failed", error);
  }
}

// Best-effort — a failure here just means the candidate falls back to tapping "I'm done"
// themselves, so it never blocks or fails the actual interviewer reply above.
async function assessRoundReady(transcript: TranscriptMessage[]): Promise<boolean> {
  try {
    const raw = await callTool(buildRoundReadinessSystem(), toLLMMessages(transcript), ROUND_READY_TOOL);
    return typeof raw === "object" && raw !== null && (raw as { ready?: unknown }).ready === true;
  } catch (error) {
    console.error("round/message: readiness check failed", error);
    return false;
  }
}
