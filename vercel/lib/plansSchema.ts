import type { StageInput } from "./plans.js";

export class PlanParseError extends Error {}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0;
}

// Some models occasionally double-encode a tool's array field — instead of
// `{"stages": [...]}` they return `{"stages": "{\"stages\":[...]}"}` (or `{"stages": "[...]"}`),
// a JSON string standing in for the array. Recover the real array from either shape rather
// than failing the whole generation over what's still perfectly usable model output.
function coerceStagesArray(rawStages: unknown): unknown {
  if (Array.isArray(rawStages)) {
    return rawStages;
  }
  if (typeof rawStages === "string") {
    try {
      const parsed = JSON.parse(rawStages);
      if (Array.isArray(parsed)) {
        return parsed;
      }
      if (typeof parsed === "object" && parsed !== null && Array.isArray((parsed as Record<string, unknown>).stages)) {
        return (parsed as Record<string, unknown>).stages;
      }
    } catch {
      // fall through to the caller's own error
    }
  }
  return rawStages;
}

// Validates the raw `submit_plan_stages` tool input into a stage list ready to insert.
export function parsePlanStages(input: unknown): StageInput[] {
  if (typeof input !== "object" || input === null) {
    throw new PlanParseError("Plan stages input is not an object");
  }
  const record = input as Record<string, unknown>;
  const stages = coerceStagesArray(record.stages);
  if (!Array.isArray(stages) || stages.length < 1) {
    throw new PlanParseError("Field stages must be a non-empty array");
  }
  return stages.map((stage, index) => {
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
