import type { VercelRequest, VercelResponse } from "@vercel/node";
import { verifyAuth } from "../../lib/auth.js";
import { callTool } from "../../lib/llmClient.js";
import { PLAN_STAGES_TOOL, buildPlanGenerationPrompt } from "../../lib/planPrompts.js";
import { parsePlanStages, PlanParseError } from "../../lib/plansSchema.js";
import { createPlan, deletePlan, saveStages } from "../../lib/plans.js";
import { ensureUserRow } from "../../lib/sessions.js";
import { isSeniority } from "../../lib/types.js";

export default async function handler(req: VercelRequest, res: VercelResponse): Promise<void> {
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  let userId: string;
  let email: string | null;
  try {
    ({ userId, email } = await verifyAuth(req));
  } catch {
    res.status(401).json({ error: "Unauthorized" });
    return;
  }

  const { roleTitle, seniority, companyContext, focusNotes } = req.body ?? {};
  if (typeof roleTitle !== "string" || roleTitle.trim().length === 0) {
    res.status(400).json({ error: "roleTitle is required" });
    return;
  }
  if (!isSeniority(seniority)) {
    res.status(400).json({ error: "seniority must be one of junior, mid, senior" });
    return;
  }
  const normalizedCompanyContext =
    typeof companyContext === "string" && companyContext.trim().length > 0 ? companyContext.trim() : null;
  const normalizedFocusNotes = typeof focusNotes === "string" && focusNotes.trim().length > 0 ? focusNotes.trim() : null;

  await ensureUserRow(userId, email);
  const planId = await createPlan({
    userId,
    roleTitle: roleTitle.trim(),
    seniority,
    companyContext: normalizedCompanyContext,
    focusNotes: normalizedFocusNotes
  });

  const system = buildPlanGenerationPrompt({
    roleTitle: roleTitle.trim(),
    seniority,
    companyContext: normalizedCompanyContext,
    focusNotes: normalizedFocusNotes
  });

  try {
    const raw = await callTool(system, [{ role: "user", content: "Generate the plan now." }], PLAN_STAGES_TOOL);
    const stages = parsePlanStages(raw);
    await saveStages(planId, stages);
    res.status(200).json({
      planId,
      stages: stages.map((stage, index) => ({ order: index, ...stage }))
    });
  } catch (error) {
    await deletePlan(planId);
    if (error instanceof PlanParseError) {
      console.error("plans/generate: malformed stages from model", error);
    } else {
      console.error("plans/generate failed", error);
    }
    res.status(502).json({ error: "Couldn't generate the plan, please try again." });
  }
}
