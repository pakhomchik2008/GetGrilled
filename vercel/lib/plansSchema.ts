import type { StageInput } from "./plans.js";

export class PlanParseError extends Error {}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0;
}

// Validates the raw `submit_plan_stages` tool input into a stage list ready to insert.
export function parsePlanStages(input: unknown): StageInput[] {
  if (typeof input !== "object" || input === null) {
    throw new PlanParseError("Plan stages input is not an object");
  }
  const record = input as Record<string, unknown>;
  if (!Array.isArray(record.stages) || record.stages.length < 1) {
    throw new PlanParseError("Field stages must be a non-empty array");
  }
  return record.stages.map((stage, index) => {
    if (typeof stage !== "object" || stage === null) {
      throw new PlanParseError(`Stage at index ${index} is not an object`);
    }
    const stageRecord = stage as Record<string, unknown>;
    if (!isNonEmptyString(stageRecord.title)) {
      throw new PlanParseError(`Stage at index ${index} is missing title`);
    }
    if (!isNonEmptyString(stageRecord.focus_description)) {
      throw new PlanParseError(`Stage at index ${index} is missing focus_description`);
    }
    return { title: stageRecord.title, focus_description: stageRecord.focus_description };
  });
}
