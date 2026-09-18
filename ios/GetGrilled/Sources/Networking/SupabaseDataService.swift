import Foundation
import Supabase

/// Read-only queries against Supabase, scoped by RLS to the signed-in user's own rows.
/// Never writes session status or feedback — those stay backend-authoritative (Vercel).
struct SupabaseDataService {
    private func client() async -> SupabaseClient {
        await SupabaseAuthProvider.shared.client
    }

    /// v2 (round-based) sessions only — `mode` is set for every session created since the
    /// redesign; legacy single-question sessions (mode IS NULL) are excluded, they have no
    /// role_title/rounds to group or show here.
    func listV2Sessions() async throws -> [V2SessionSummary] {
        _ = try await SupabaseAuthProvider.shared.ensureSession()
        let client = await self.client()
        return try await client
            .from("interview_sessions")
            .select("id, role_title, seniority, mode, status, started_at, completed_at, overall_summary, session_rounds(round_type, round_order, status, self_eval, feedback_status, feedback_notes)")
            .isDistinct("mode", value: "null")
            .order("started_at", ascending: false)
            .execute()
            .value
    }

    /// The most recent LEGACY (v1, single-question) session that hasn't reached a terminal state.
    /// v2 sessions (mode is set) use session_rounds instead of transcript and aren't resumable
    /// through this path yet — resuming mid-round-flow isn't built here.
    func latestResumableSession() async throws -> SessionDetail? {
        _ = try await SupabaseAuthProvider.shared.ensureSession()
        let client = await self.client()
        let sessions: [SessionDetail] = try await client
            .from("interview_sessions")
            .select("id, difficulty, status, transcript")
            .in("status", values: ["started", "in_progress", "awaiting_feedback"])
            .is("mode", value: nil)
            .order("started_at", ascending: false)
            .limit(1)
            .execute()
            .value
        return sessions.first
    }

    func listPlans() async throws -> [PrepPlanSummary] {
        _ = try await SupabaseAuthProvider.shared.ensureSession()
        let client = await self.client()
        return try await client
            .from("prep_plans")
            .select("id, role_title, seniority, company_context, focus_notes, created_at, plan_stages(*)")
            .order("created_at", ascending: false)
            .execute()
            .value
    }
}
