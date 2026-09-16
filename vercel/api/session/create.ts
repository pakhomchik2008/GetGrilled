import type { VercelRequest, VercelResponse } from "@vercel/node";
import { verifyAuth } from "../../lib/auth.js";
import { ROUND_ORDER, isSeniority, isSessionMode } from "../../lib/types.js";
import { createRoundsForSession, getRoundByOrder } from "../../lib/rounds.js";
import { createV2Session, ensureUserRow } from "../../lib/sessions.js";
import { getPlan, getStage } from "../../lib/plans.js";

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

  const { mode, roleTitle, seniority, focusNotes, planStageId } = req.body ?? {};
  if (!isSessionMode(mode)) {
    res.status(400).json({ error: "mode must be one of test, competition" });
    return;
  }
  if (typeof roleTitle !== "string" || roleTitle.trim().length === 0) {
    res.status(400).json({ error: "roleTitle is required" });
    return;
  }
  if (!isSeniority(seniority)) {
    res.status(400).json({ error: "seniority must be one of junior, mid, senior" });
    return;
  }
  if (planStageId !== undefined && planStageId !== null && typeof planStageId !== "string") {
    res.status(400).json({ error: "planStageId must be a string or null" });
    return;
  }

  if (planStageId) {
    const stage = await getStage(planStageId);
    if (!stage) {
      res.status(404).json({ error: "Plan stage not found" });
      return;
    }
    const plan = await getPlan(stage.plan_id);
    if (!plan || plan.user_id !== userId) {
      res.status(404).json({ error: "Plan stage not found" });
      return;
    }
    if (stage.status === "completed") {
      res.status(409).json({ error: "This stage is already completed" });
      return;
    }
  }

  await ensureUserRow(userId, email);
  const sessionId = await createV2Session({
    userId,
    mode,
    roleTitle: roleTitle.trim(),
    seniority,
    focusNotes: typeof focusNotes === "string" && focusNotes.trim().length > 0 ? focusNotes.trim() : null,
    planStageId: planStageId ?? null
  });
  await createRoundsForSession(sessionId);
  const firstRound = await getRoundByOrder(sessionId, 0);
  if (!firstRound) {
    res.status(500).json({ error: "Failed to initialize rounds" });
    return;
  }

  res.status(200).json({
    sessionId,
    round: { id: firstRound.id, type: firstRound.round_type, order: firstRound.round_order },
    totalRounds: ROUND_ORDER.length
  });
}
