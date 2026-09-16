import { supabaseAdmin } from "./supabaseAdmin.js";
import { difficultyForSeniority } from "./types.js";
import type {
  Difficulty,
  InterviewSessionRow,
  Seniority,
  SessionFeedback,
  SessionMode,
  SessionStatus,
  TranscriptMessage
} from "./types.js";

export async function ensureUserRow(userId: string, email: string | null): Promise<void> {
  const { error } = await supabaseAdmin
    .from("users")
    .upsert({ id: userId, email: email ?? "" }, { onConflict: "id", ignoreDuplicates: true });
  if (error) throw error;
}

export async function createSession(userId: string, difficulty: Difficulty): Promise<string> {
  const { data, error } = await supabaseAdmin
    .from("interview_sessions")
    .insert({ user_id: userId, difficulty, status: "started" })
    .select("id")
    .single();
  if (error || !data) throw error ?? new Error("Failed to create session");
  return data.id as string;
}

export interface CreateV2SessionInput {
  userId: string;
  mode: SessionMode;
  roleTitle: string;
  seniority: Seniority;
  focusNotes: string | null;
  planStageId: string | null;
}

export async function createV2Session(input: CreateV2SessionInput): Promise<string> {
  const { data, error } = await supabaseAdmin
    .from("interview_sessions")
    .insert({
      user_id: input.userId,
      difficulty: difficultyForSeniority(input.seniority),
      status: "started",
      mode: input.mode,
      role_title: input.roleTitle,
      seniority: input.seniority,
      focus_notes: input.focusNotes,
      plan_stage_id: input.planStageId
    })
    .select("id")
    .single();
  if (error || !data) throw error ?? new Error("Failed to create session");
  return data.id as string;
}

export async function getSession(sessionId: string): Promise<InterviewSessionRow | null> {
  const { data, error } = await supabaseAdmin
    .from("interview_sessions")
    .select("*")
    .eq("id", sessionId)
    .maybeSingle();
  if (error) throw error;
  return data as InterviewSessionRow | null;
}

export async function appendTranscriptMessage(sessionId: string, transcript: TranscriptMessage[], message: TranscriptMessage): Promise<void> {
  const updated = [...transcript, message];
  const { error } = await supabaseAdmin
    .from("interview_sessions")
    .update({ transcript: updated })
    .eq("id", sessionId);
  if (error) throw error;
}

export async function setQuestionText(sessionId: string, questionText: string): Promise<void> {
  const { error } = await supabaseAdmin
    .from("interview_sessions")
    .update({ question_text: questionText })
    .eq("id", sessionId);
  if (error) throw error;
}

export async function setStatus(sessionId: string, status: SessionStatus, completedAt?: string): Promise<void> {
  const patch: Record<string, unknown> = { status };
  if (completedAt) patch.completed_at = completedAt;
  const { error } = await supabaseAdmin.from("interview_sessions").update(patch).eq("id", sessionId);
  if (error) throw error;
}

export async function saveFeedback(sessionId: string, feedback: SessionFeedback): Promise<void> {
  const { error } = await supabaseAdmin.from("session_feedback").insert({ session_id: sessionId, ...feedback });
  if (error) throw error;
}

export async function logEvent(userId: string, sessionId: string, eventType: "session_started" | "session_completed"): Promise<void> {
  const { error } = await supabaseAdmin
    .from("analytics_events")
    .insert({ user_id: userId, session_id: sessionId, event_type: eventType });
  if (error) throw error;
}
