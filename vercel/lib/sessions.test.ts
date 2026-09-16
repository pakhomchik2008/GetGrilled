import { beforeEach, describe, expect, it, vi } from "vitest";

// Chainable fake matching how sessions.ts calls the Supabase query builder:
// getSubscriptionStatus awaits after .maybeSingle(), countRecentSessions awaits
// the chain itself (no terminal call), so the builder must be thenable too.
function makeQueryResult(result: { data?: unknown; count?: number; error?: unknown }) {
  const builder: any = {
    select: vi.fn(() => builder),
    eq: vi.fn(() => builder),
    neq: vi.fn(() => builder),
    gte: vi.fn(() => builder),
    update: vi.fn(() => builder),
    maybeSingle: vi.fn(async () => ({ data: result.data ?? null, error: result.error ?? null })),
    then: (resolve: (value: unknown) => void) => resolve({ count: result.count ?? 0, error: result.error ?? null })
  };
  return builder;
}

let fromResults: Record<string, ReturnType<typeof makeQueryResult>[]> = {};

vi.mock("./supabaseAdmin.js", () => ({
  supabaseAdmin: {
    from: vi.fn((table: string) => {
      const queue = fromResults[table] ?? [];
      return queue.shift() ?? makeQueryResult({ count: 0 });
    })
  }
}));

import { checkWeeklyLimit } from "./sessions.js";

beforeEach(() => {
  fromResults = {};
});

describe("checkWeeklyLimit", () => {
  it("allows a free user under the test-mode limit (3/week)", async () => {
    fromResults.users = [makeQueryResult({ data: { subscription_status: "free" } })];
    fromResults.interview_sessions = [makeQueryResult({ count: 2 })];
    const result = await checkWeeklyLimit("user-1", "test", "session-x");
    expect(result).toEqual({ allowed: true, limit: 3, used: 2 });
  });

  it("blocks a free user at the test-mode limit", async () => {
    fromResults.users = [makeQueryResult({ data: { subscription_status: "free" } })];
    fromResults.interview_sessions = [makeQueryResult({ count: 3 })];
    const result = await checkWeeklyLimit("user-1", "test", "session-x");
    expect(result.allowed).toBe(false);
    expect(result.limit).toBe(3);
  });

  it("blocks a free user at the competition-mode limit (2/week)", async () => {
    fromResults.users = [makeQueryResult({ data: { subscription_status: "free" } })];
    fromResults.interview_sessions = [makeQueryResult({ count: 2 })];
    const result = await checkWeeklyLimit("user-1", "competition", "session-x");
    expect(result).toEqual({ allowed: false, limit: 2, used: 2 });
  });

  it("treats a missing users row as free", async () => {
    fromResults.users = [makeQueryResult({ data: null })];
    fromResults.interview_sessions = [makeQueryResult({ count: 3 })];
    const result = await checkWeeklyLimit("user-1", "test", "session-x");
    expect(result.allowed).toBe(false);
  });

  it("always allows a paid user without counting sessions", async () => {
    fromResults.users = [makeQueryResult({ data: { subscription_status: "paid" } })];
    const result = await checkWeeklyLimit("user-1", "competition", "session-x");
    expect(result).toEqual({ allowed: true, limit: 2, used: 0 });
  });

  it("excludes the session being checked from its own count", async () => {
    fromResults.users = [makeQueryResult({ data: { subscription_status: "free" } })];
    const sessionsBuilder = makeQueryResult({ count: 2 });
    fromResults.interview_sessions = [sessionsBuilder];
    await checkWeeklyLimit("user-1", "test", "session-x");
    expect(sessionsBuilder.neq).toHaveBeenCalledWith("id", "session-x");
  });
});
