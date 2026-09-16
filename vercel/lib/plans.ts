import { supabaseAdmin } from "./supabaseAdmin.js";
import type { PlanStageRow, PrepPlanRow, Seniority } from "./types.js";

export interface CreatePlanInput {
  userId: string;
  roleTitle: string;
  seniority: Seniority;
  companyContext: string | null;
  focusNotes: string | null;
}

export async function createPlan(input: CreatePlanInput): Promise<string> {
  const { data, error } = await supabaseAdmin
    .from("prep_plans")
    .insert({
      user_id: input.userId,
      role_title: input.roleTitle,
      seniority: input.seniority,
      company_context: input.companyContext,
      focus_notes: input.focusNotes
    })
    .select("id")
    .single();
  if (error || !data) throw error ?? new Error("Failed to create plan");
  return data.id as string;
}

export interface StageInput {
  title: string;
  focus_description: string;
}

export async function saveStages(planId: string, stages: StageInput[]): Promise<void> {
  const rows = stages.map((stage, index) => ({
    plan_id: planId,
    stage_order: index,
    title: stage.title,
    focus_description: stage.focus_description
  }));
  const { error } = await supabaseAdmin.from("plan_stages").insert(rows);
  if (error) throw error;
}

export async function getPlan(planId: string): Promise<PrepPlanRow | null> {
  const { data, error } = await supabaseAdmin.from("prep_plans").select("*").eq("id", planId).maybeSingle();
  if (error) throw error;
  return data as PrepPlanRow | null;
}

export async function getStage(stageId: string): Promise<PlanStageRow | null> {
  const { data, error } = await supabaseAdmin.from("plan_stages").select("*").eq("id", stageId).maybeSingle();
  if (error) throw error;
  return data as PlanStageRow | null;
}

export async function markStageCompleted(stageId: string, sessionId: string): Promise<void> {
  const { error } = await supabaseAdmin
    .from("plan_stages")
    .update({ status: "completed", session_id: sessionId })
    .eq("id", stageId);
  if (error) throw error;
}

// Deletes an owner-verified plan whose stage generation failed, so it doesn't linger with zero stages.
export async function deletePlan(planId: string): Promise<void> {
  const { error } = await supabaseAdmin.from("prep_plans").delete().eq("id", planId);
  if (error) throw error;
}
