import type { VercelRequest } from "@vercel/node";
import { supabaseAdmin } from "./supabaseAdmin.js";

export class AuthError extends Error {}

// Verifies the Supabase JWT the client attached and returns the authenticated user's id.
export async function verifyAuth(req: VercelRequest): Promise<{ userId: string; email: string | null }> {
  const header = req.headers.authorization;
  if (!header?.startsWith("Bearer ")) {
    throw new AuthError("Missing bearer token");
  }
  const token = header.slice("Bearer ".length);
  const { data, error } = await supabaseAdmin.auth.getUser(token);
  if (error || !data.user) {
    throw new AuthError("Invalid or expired token");
  }
  return { userId: data.user.id, email: data.user.email ?? null };
}
