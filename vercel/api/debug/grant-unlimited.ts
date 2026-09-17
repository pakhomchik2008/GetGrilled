import type { VercelRequest, VercelResponse } from "@vercel/node";
import { verifyAuth } from "../../lib/auth.js";
import { ensureUserRow, setSubscriptionStatus } from "../../lib/sessions.js";

/**
 * Dev-only self-service toggle so the caller can flip their OWN account's tier without going
 * through StoreKit/RevenueCat sandbox setup. Auth-gated to the caller's own userId — never
 * takes a target id, so it can't be used to grant/revoke anyone else. Remove before App Store
 * submission (see docs/v2-technical-spec.md §8 — RevenueCat is the real gate).
 */
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

  const { status } = req.body ?? {};
  const target = status === "free" ? "free" : "paid";
  // setSubscriptionStatus is an UPDATE — a no-op if this account has never created a session
  // yet (no users row), so ensure the row exists first, same as session/create.ts does.
  await ensureUserRow(userId, email);
  await setSubscriptionStatus(userId, target);
  res.status(200).json({ subscriptionStatus: target });
}
