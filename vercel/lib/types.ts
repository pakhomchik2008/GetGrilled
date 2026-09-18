export type Difficulty = "easy" | "medium" | "hard";

export type SessionStatus = "started" | "in_progress" | "awaiting_feedback" | "completed";

export type Seniority = "junior" | "mid" | "senior";
export type SessionMode = "test" | "competition";
export type RoundType = "intro" | "technical" | "behavioral";
export type RoundStatus = "pending" | "in_progress" | "completed" | "skipped";
export type SelfEval = "rough" | "ok" | "strong";
export type RoundFeedbackStatus = "strong" | "good" | "needs_work";

export const ROUND_ORDER: RoundType[] = ["intro", "technical", "behavioral"];

export type ImageMediaType = "image/jpeg" | "image/png";

export interface TranscriptImage {
  mediaType: ImageMediaType;
  base64: string;
}

export interface TranscriptMessage {
  role: "interviewer" | "candidate";
  content: string;
  timestamp: string;
  /** A screenshot the candidate attached to this turn (e.g. a diagram) — optional. */
  image?: TranscriptImage;
}

export interface SessionFeedback {
  correctness_score: number;
  correctness_notes: string;
  communication_score: number;
  communication_notes: string;
  efficiency_score: number;
  efficiency_notes: string;
  overall_summary: string;
}

export interface RoundFeedback {
  status: RoundFeedbackStatus;
  notes: string;
}

export interface InterviewSessionRow {
  id: string;
  user_id: string;
  difficulty: Difficulty;
  topic: string | null;
  status: SessionStatus;
  question_text: string | null;
  transcript: TranscriptMessage[];
  started_at: string;
  completed_at: string | null;
  mode: SessionMode | null;
  role_title: string | null;
  seniority: Seniority | null;
  focus_notes: string | null;
  plan_stage_id: string | null;
  /** Text pulled from an attached job-posting PDF or link — tone/domain context only. */
  job_context: string | null;
  /** The synthesized cross-round summary from session/finish — null until the session completes. */
  overall_summary: string | null;
}

export interface SessionRoundRow {
  id: string;
  session_id: string;
  round_type: RoundType;
  round_order: number;
  transcript: TranscriptMessage[];
  self_eval: SelfEval | null;
  feedback_status: RoundFeedbackStatus | null;
  feedback_notes: string | null;
  status: RoundStatus;
  started_at: string | null;
  completed_at: string | null;
}

export interface PrepPlanRow {
  id: string;
  user_id: string;
  role_title: string;
  seniority: Seniority;
  company_context: string | null;
  focus_notes: string | null;
  created_at: string;
}

export interface PlanStageRow {
  id: string;
  plan_id: string;
  stage_order: number;
  title: string;
  focus_description: string;
  status: "pending" | "completed";
  session_id: string | null;
}

export function isDifficulty(value: unknown): value is Difficulty {
  return value === "easy" || value === "medium" || value === "hard";
}

export function isSeniority(value: unknown): value is Seniority {
  return value === "junior" || value === "mid" || value === "senior";
}

export function isSessionMode(value: unknown): value is SessionMode {
  return value === "test" || value === "competition";
}

export function isRoundType(value: unknown): value is RoundType {
  return value === "intro" || value === "technical" || value === "behavioral";
}

export function isImageMediaType(value: unknown): value is ImageMediaType {
  return value === "image/jpeg" || value === "image/png";
}

export function difficultyForSeniority(seniority: Seniority): Difficulty {
  switch (seniority) {
    case "junior":
      return "easy";
    case "mid":
      return "medium";
    case "senior":
      return "hard";
  }
}
