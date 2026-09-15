import Foundation
import Supabase

/// Wraps the Supabase client and guarantees a valid session for every backend call.
///
/// Phase 1 has no sign-in UI yet (that's Phase 2), but the architecture requires every
/// Vercel request to carry a verified Supabase JWT. Anonymous auth bridges that gap: it
/// gives every install a real `auth.users` row and access token from day one, and
/// Supabase supports converting an anonymous session into a permanent account later
/// (email/password or Sign in with Apple) without changing the user's id.
actor SupabaseAuthProvider {
    static let shared = SupabaseAuthProvider()

    let client = SupabaseClient(supabaseURL: Config.supabaseURL, supabaseKey: Config.supabaseAnonKey)

    /// Returns a valid access token, signing in anonymously on first use.
    func accessToken() async throws -> String {
        if let session = client.auth.currentSession {
            return session.accessToken
        }
        do {
            let session = try await client.auth.session
            return session.accessToken
        } catch {
            let session = try await client.auth.signInAnonymously()
            return session.accessToken
        }
    }
}
