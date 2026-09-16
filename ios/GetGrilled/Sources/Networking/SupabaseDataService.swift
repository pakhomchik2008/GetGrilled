import Foundation
import Supabase

/// Read-only queries against Supabase, scoped by RLS to the signed-in user's own rows.
/// Never writes session status or feedback — those stay backend-authoritative (Vercel).
struct SupabaseDataService {
    private func client() async -> SupabaseClient {
        await SupabaseAuthProvider.shared.client
    }

    func listSessions() async throws -> [SessionSummary] {
        _ = try await SupabaseAuthProvider.shared.ensureSession()
        let client = await self.client()
        return try await client
            .from("interview_sessions")
            .select("id, difficulty, status, started_at, completed_at, session_feedback(*)")
            .order("started_at", ascending: false)
            .execute()
            .value
    }

    /// The most recent session that hasn't reached a terminal state, if any.
    func latestResumableSession() async throws -> SessionDetail? {
        _ = try await SupabaseAuthProvider.shared.ensureSession()
        let client = await self.client()
        let sessions: [SessionDetail] = try await client
            .from("interview_sessions")
            .select("id, difficulty, status, transcript")
            .in("status", values: ["started", "in_progress", "awaiting_feedback"])
            .order("started_at", ascending: false)
            .limit(1)
            .execute()
            .value
        return sessions.first
    }
}
