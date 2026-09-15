import type { SessionFeedback } from "./types.js";

export class FeedbackParseError extends Error {}

function isScore(value: unknown): value is number {
  return typeof value === "number" && Number.isInteger(value) && value >= 0 && value <= 100;
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0;
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
