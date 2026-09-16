import { describe, expect, it } from "vitest";
import { FeedbackParseError, parseFeedbackToolInput, parseRoundFeedback, parseSessionSummary } from "./feedbackSchema.js";

const validInput = {
  correctness_score: 80,
  correctness_notes: "Handles the general case correctly.",
  communication_score: 90,
  communication_notes: "Explained the approach clearly before coding.",
  efficiency_score: 70,
  efficiency_notes: "O(n^2) where O(n) was available.",
  overall_summary: "Solid attempt overall."
};

describe("parseFeedbackToolInput", () => {
  it("accepts well-formed tool input", () => {
    expect(parseFeedbackToolInput(validInput)).toEqual(validInput);
  });

  it("rejects a non-object input", () => {
    expect(() => parseFeedbackToolInput("not an object")).toThrow(FeedbackParseError);
    expect(() => parseFeedbackToolInput(null)).toThrow(FeedbackParseError);
  });

  it("rejects a score outside 0-100", () => {
    expect(() => parseFeedbackToolInput({ ...validInput, correctness_score: 150 })).toThrow(FeedbackParseError);
    expect(() => parseFeedbackToolInput({ ...validInput, efficiency_score: -1 })).toThrow(FeedbackParseError);
  });

  it("rejects a non-integer score", () => {
    expect(() => parseFeedbackToolInput({ ...validInput, communication_score: 85.5 })).toThrow(FeedbackParseError);
  });

  it("rejects an empty notes field instead of silently accepting it", () => {
    expect(() => parseFeedbackToolInput({ ...validInput, overall_summary: "" })).toThrow(FeedbackParseError);
  });

  it("rejects a missing field", () => {
    const { overall_summary, ...withoutSummary } = validInput;
    expect(() => parseFeedbackToolInput(withoutSummary)).toThrow(FeedbackParseError);
  });
});

describe("parseRoundFeedback", () => {
  const validRound = { status: "strong", notes: "Clear, concise, good energy." };

  it("accepts well-formed round feedback", () => {
    expect(parseRoundFeedback(validRound)).toEqual(validRound);
  });

  it("rejects an invalid status value", () => {
    expect(() => parseRoundFeedback({ ...validRound, status: "amazing" })).toThrow(FeedbackParseError);
  });

  it("rejects a missing status", () => {
    const { status, ...withoutStatus } = validRound;
    expect(() => parseRoundFeedback(withoutStatus)).toThrow(FeedbackParseError);
  });

  it("rejects empty notes", () => {
    expect(() => parseRoundFeedback({ ...validRound, notes: "" })).toThrow(FeedbackParseError);
  });

  it("rejects a non-object input", () => {
    expect(() => parseRoundFeedback(null)).toThrow(FeedbackParseError);
    expect(() => parseRoundFeedback("strong")).toThrow(FeedbackParseError);
  });
});

describe("parseSessionSummary", () => {
  it("accepts a well-formed summary", () => {
    expect(parseSessionSummary({ overall_summary: "Solid across all three rounds." })).toBe(
      "Solid across all three rounds."
    );
  });

  it("rejects an empty summary", () => {
    expect(() => parseSessionSummary({ overall_summary: "" })).toThrow(FeedbackParseError);
  });

  it("rejects a missing field", () => {
    expect(() => parseSessionSummary({})).toThrow(FeedbackParseError);
  });
});
