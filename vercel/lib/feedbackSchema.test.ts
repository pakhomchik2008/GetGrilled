import { describe, expect, it } from "vitest";
import { FeedbackParseError, parseFeedbackToolInput } from "./feedbackSchema.js";

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
