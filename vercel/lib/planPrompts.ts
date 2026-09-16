import type { Seniority } from "./types.js";

export interface GeneratePlanInput {
  roleTitle: string;
  seniority: Seniority;
  companyContext: string | null;
  focusNotes: string | null;
}

export function buildPlanGenerationPrompt(input: GeneratePlanInput): string {
  const lines = [
    `You are designing a mock-interview prep plan for a candidate targeting: ${input.roleTitle} (${input.seniority} level).`
  ];
  if (input.companyContext?.trim()) {
    lines.push(
      `They mentioned this company/context for tone and domain flavor only: "${input.companyContext.trim()}". ` +
        `Do NOT claim these stages or any question reflects that company's actual, real interview process — you have no ` +
        `knowledge of it and must not imply otherwise. Use it only to pick a plausible domain (e.g. fintech, social, infra).`
    );
  }
  if (input.focusNotes?.trim()) {
    lines.push(`They want to focus on: ${input.focusNotes.trim()}`);
  }
  lines.push(
    "Generate 5 to 8 stages that together form a sensible prep plan for this role and level — a mix of coding topics " +
      "(pick from: arrays/strings, hash tables, two pointers, trees/graphs, dynamic programming, recursion/backtracking, " +
      "concurrency, system-design basics for mid/senior) and 1-2 behavioral-style stages. Each stage needs a short title " +
      "(3-6 words) and a one-sentence focus_description of what it covers. Order them roughly easy-to-hard. " +
      "Call submit_plan_stages with the result — never write it as chat text."
  );
  return lines.join("\n\n");
}

export const PLAN_STAGES_TOOL = {
  name: "submit_plan_stages",
  description: "The generated list of prep-plan stages",
  input_schema: {
    type: "object" as const,
    required: ["stages"],
    properties: {
      stages: {
        type: "array",
        minItems: 5,
        maxItems: 8,
        items: {
          type: "object",
          required: ["title", "focus_description"],
          properties: {
            title: { type: "string" },
            focus_description: { type: "string" }
          }
        }
      }
    }
  }
};
