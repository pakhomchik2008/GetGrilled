import type { RoundFeedback, RoundFeedbackStatus, SessionFeedback } from "./types.js";

export class FeedbackParseError extends Error {}

function isScore(value: unknown): value is number {
  return typeof value === "number" && Number.isInteger(value) && value >= 0 && value <= 100;
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0;
}

function isRoundFeedbackStatus(value: unknown): value is RoundFeedbackStatus {
  return value === "strong" || value === "good" || value === "needs_work";
}

// Validates the raw `submit_feedback` tool input from Claude into a SessionFeedback.
// Throws FeedbackParseError with a field-specific message on any mismatch, rather than
// silently coercing — a malformed score should fail loudly, not save as 0.
export function parseFeedbackToolInput(input: unknown): SessionFeedback {
  if (typeof input !== "object" || input === null) {
    throw new FeedbackParseError("Feedback input is not an object");
  }
  const record = input as Record<string, unknown>;

  const stringFields = [
    "correctness_notes",
    "communication_notes",
    "efficiency_notes",
    "overall_summary"
  ] as const;
  for (const field of stringFields) {
    if (!isNonEmptyString(record[field])) {
      throw new FeedbackParseError(`Missing or empty field: ${field}`);
    }
  }

  const scoreFields = ["correctness_score", "communication_score", "efficiency_score"] as const;
  for (const field of scoreFields) {
    if (!isScore(record[field])) {
      throw new FeedbackParseError(`Field ${field} must be an integer between 0 and 100`);
    }
  }

  return {
    correctness_score: record.correctness_score as number,
    correctness_notes: record.correctness_notes as string,
    communication_score: record.communication_score as number,
    communication_notes: record.communication_notes as string,
    efficiency_score: record.efficiency_score as number,
    efficiency_notes: record.efficiency_notes as string,
    overall_summary: record.overall_summary as string
  };
}

// Validates the raw `submit_round_feedback` tool input for a single round.
export function parseRoundFeedback(input: unknown): RoundFeedback {
  if (typeof input !== "object" || input === null) {
    throw new FeedbackParseError("Round feedback input is not an object");
  }
  const record = input as Record<string, unknown>;
  if (!isRoundFeedbackStatus(record.status)) {
    throw new FeedbackParseError("Field status must be one of strong, good, needs_work");
  }
  if (!isNonEmptyString(record.notes)) {
    throw new FeedbackParseError("Missing or empty field: notes");
  }
  return { status: record.status, notes: record.notes };
}

// Validates the raw `submit_session_summary` tool input.
export function parseSessionSummary(input: unknown): string {
  if (typeof input !== "object" || input === null) {
    throw new FeedbackParseError("Session summary input is not an object");
  }
  const record = input as Record<string, unknown>;
  if (!isNonEmptyString(record.overall_summary)) {
    throw new FeedbackParseError("Missing or empty field: overall_summary");
  }
  return record.overall_summary;
}
