import { describe, expect, it } from "vitest";
import { PlanParseError, parsePlanStages } from "./plansSchema.js";

const validInput = {
  stages: [
    { title: "Recruiter-style intro", focus_description: "Background, motivation" },
    { title: "Coding — arrays & hashing", focus_description: "Two Sum, variants" },
    { title: "Coding — system design basics", focus_description: "Rate limiter, cache" },
    { title: "Behavioral — conflict & ownership", focus_description: "A past disagreement" },
    { title: "Coding — concurrency", focus_description: "Race conditions, locks" }
  ]
};

describe("parsePlanStages", () => {
  it("accepts a well-formed stage list", () => {
    expect(parsePlanStages(validInput)).toEqual(validInput.stages);
  });

  it("rejects a non-object input", () => {
    expect(() => parsePlanStages(null)).toThrow(PlanParseError);
    expect(() => parsePlanStages("stages")).toThrow(PlanParseError);
  });

  it("rejects a missing or empty stages array", () => {
    expect(() => parsePlanStages({})).toThrow(PlanParseError);
    expect(() => parsePlanStages({ stages: [] })).toThrow(PlanParseError);
    expect(() => parsePlanStages({ stages: "nope" })).toThrow(PlanParseError);
  });

  it("rejects a stage missing a title", () => {
    const broken = { stages: [{ focus_description: "no title here" }] };
    expect(() => parsePlanStages(broken)).toThrow(PlanParseError);
  });

  it("rejects a stage missing focus_description", () => {
    const broken = { stages: [{ title: "Missing description" }] };
    expect(() => parsePlanStages(broken)).toThrow(PlanParseError);
  });

  it("rejects a stage with an empty title", () => {
    const broken = { stages: [{ title: "", focus_description: "still empty title" }] };
    expect(() => parsePlanStages(broken)).toThrow(PlanParseError);
  });
});
