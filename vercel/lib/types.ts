export type Difficulty = "easy" | "medium" | "hard";

export type SessionStatus = "started" | "in_progress" | "awaiting_feedback" | "completed";

export interface TranscriptMessage {
  role: "interviewer" | "candidate";
  content: string;
  timestamp: string;
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
}

export function isDifficulty(value: unknown): value is Difficulty {
  return value === "easy" || value === "medium" || value === "hard";
}
