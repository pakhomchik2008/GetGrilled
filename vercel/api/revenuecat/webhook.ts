import type { VercelRequest, VercelResponse } from "@vercel/node";
import { setSubscriptionStatus } from "../../lib/sessions.js";

// RevenueCat calls this with the "Authorization Header Value" you set in
// RevenueCat > Project settings > Webhooks. Not a user JWT — a shared secret.
const WEBHOOK_SECRET = process.env.REVENUECAT_WEBHOOK_SECRET;

const PAID_EVENT_TYPES = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "UNCANCELLATION",
  "PRODUCT_CHANGE",
  "TRANSFER"
]);
const FREE_EVENT_TYPES = new Set(["EXPIRATION"]);

interface RevenueCatEvent {
  type: string;
  app_user_id: string;
}

export default async function handler(req: VercelRequest, res: VercelResponse): Promise<void> {
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  if (!WEBHOOK_SECRET) {
    console.error("revenuecat/webhook: REVENUECAT_WEBHOOK_SECRET is not configured");
    res.status(500).json({ error: "Webhook not configured" });
    return;
  }
  if (req.headers.authorization !== `Bearer ${WEBHOOK_SECRET}`) {
    res.status(401).json({ error: "Unauthorized" });
    return;
  }

  const event = (req.body as { event?: RevenueCatEvent } | undefined)?.event;
  if (!event || typeof event.type !== "string" || typeof event.app_user_id !== "string") {
    res.status(400).json({ error: "Malformed webhook payload" });
    return;
  }

  // app_user_id is the Supabase auth uid the iOS client passes to Purchases.configure/logIn.
  const userId = event.app_user_id;

  if (PAID_EVENT_TYPES.has(event.type)) {
    await setSubscriptionStatus(userId, "paid");
  } else if (FREE_EVENT_TYPES.has(event.type)) {
    await setSubscriptionStatus(userId, "free");
  }
  // CANCELLATION / BILLING_ISSUE / other event types: entitlement doesn't
  // change yet (still active until EXPIRATION), so no-op.

  res.status(200).json({ received: true });
}
