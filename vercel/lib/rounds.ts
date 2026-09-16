import { supabaseAdmin } from "./supabaseAdmin.js";
import { ROUND_ORDER } from "./types.js";
import type { RoundFeedback, RoundStatus, SelfEval, SessionRoundRow, TranscriptMessage } from "./types.js";

export async function createRoundsForSession(sessionId: string): Promise<void> {
  const rows = ROUND_ORDER.map((roundType, index) => ({
    session_id: sessionId,
    round_type: roundType,
    round_order: index,
    status: index === 0 ? "in_progress" : "pending"
  }));
  const { error } = await supabaseAdmin.from("session_rounds").insert(rows);
  if (error) throw error;
}

export async function getRound(roundId: string): Promise<SessionRoundRow | null> {
  const { data, error } = await supabaseAdmin.from("session_rounds").select("*").eq("id", roundId).maybeSingle();
  if (error) throw error;
  return data as SessionRoundRow | null;
}

export async function getRoundByOrder(sessionId: string, roundOrder: number): Promise<SessionRoundRow | null> {
  const { data, error } = await supabaseAdmin
    .from("session_rounds")
    .select("*")
    .eq("session_id", sessionId)
    .eq("round_order", roundOrder)
    .maybeSingle();
  if (error) throw error;
  return data as SessionRoundRow | null;
}

export async function listRounds(sessionId: string): Promise<SessionRoundRow[]> {
  const { data, error } = await supabaseAdmin
    .from("session_rounds")
    .select("*")
    .eq("session_id", sessionId)
    .order("round_order", { ascending: true });
  if (error) throw error;
  return (data ?? []) as SessionRoundRow[];
}

export async function appendRoundTranscript(
  roundId: string,
  transcript: TranscriptMessage[],
  message: TranscriptMessage
): Promise<void> {
  const updated = [...transcript, message];
  const { error } = await supabaseAdmin.from("session_rounds").update({ transcript: updated }).eq("id", roundId);
  if (error) throw error;
}

export async function markRoundStarted(roundId: string, startedAt: string): Promise<void> {
  const { error } = await supabaseAdmin
    .from("session_rounds")
    .update({ status: "in_progress", started_at: startedAt })
    .eq("id", roundId);
  if (error) throw error;
}

export async function saveRoundFeedback(
  roundId: string,
  feedback: RoundFeedback,
  selfEval: SelfEval | null,
  completedAt: string
): Promise<void> {
  const { error } = await supabaseAdmin
    .from("session_rounds")
    .update({
      status: "completed",
      feedback_status: feedback.status,
      feedback_notes: feedback.notes,
      self_eval: selfEval,
      completed_at: completedAt
    })
    .eq("id", roundId);
  if (error) throw error;
}

export async function markRoundSkipped(roundId: string, selfEval: SelfEval | null, completedAt: string): Promise<void> {
  const { error } = await supabaseAdmin
    .from("session_rounds")
    .update({ status: "skipped", self_eval: selfEval, completed_at: completedAt })
    .eq("id", roundId);
  if (error) throw error;
}

export async function setRoundStatus(roundId: string, status: RoundStatus): Promise<void> {
  const { error } = await supabaseAdmin.from("session_rounds").update({ status }).eq("id", roundId);
  if (error) throw error;
}

// Starts the next pending round after the given order, if any. Returns its id, or null if none left.
export async function activateNextRound(sessionId: string, afterOrder: number, startedAt: string): Promise<SessionRoundRow | null> {
  const rounds = await listRounds(sessionId);
  const next = rounds.find((round) => round.round_order > afterOrder && round.status === "pending");
  if (!next) return null;
  await markRoundStarted(next.id, startedAt);
  return { ...next, status: "in_progress", started_at: startedAt };
}
