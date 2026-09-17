import Foundation
import Supabase

/// Wraps the Supabase client and guarantees a valid session for every backend call.
///
/// Every install starts with an anonymous session (a real `auth.users` id/JWT with no
/// sign-in friction), which `signUp`/`signInWithApple` then upgrade in place via Supabase's
/// identity-linking so the user id never changes. `signIn` (an existing account) replaces
/// the anonymous session outright, same as any other provider.
actor SupabaseAuthProvider {
    static let shared = SupabaseAuthProvider()

    let client = SupabaseClient(supabaseURL: Config.supabaseURL, supabaseKey: Config.supabaseAnonKey)

    /// Returns a valid access token, signing in anonymously on first use.
    func accessToken() async throws -> String {
        try await ensureSession().accessToken
    }

    /// `client.auth.session` already returns the cached session as-is when still valid and
    /// transparently refreshes it via the stored refresh token when expired — unlike
    /// `client.auth.currentSession`, which is a synchronous read of whatever's cached, expired
    /// or not (its own doc comment says as much). Only falls through to a fresh anonymous
    /// sign-in when there's truly no session to refresh (`.sessionMissing`, e.g. first launch).
    @discardableResult
    func ensureSession() async throws -> Session {
        do {
            return try await client.auth.session
        } catch {
            return try await client.auth.signInAnonymously()
        }
    }

    var currentUser: User? {
        client.auth.currentUser
    }

    /// Upgrades the current anonymous session to a real account, or creates one if signed out.
    func signUp(email: String, password: String) async throws {
        _ = try await ensureSession()
        if client.auth.currentUser?.isAnonymous == true {
            _ = try await client.auth.update(user: UserAttributes(email: email, password: password))
        } else {
            try await client.auth.signUp(email: email, password: password)
        }
    }

    /// Signs into an existing account, replacing whatever session (anonymous or none) was active.
    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }

    /// Links Sign in with Apple to the current anonymous session, or signs in if already permanent.
    func signInWithApple(idToken: String, nonce: String) async throws {
        _ = try await ensureSession()
        let credentials = OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce)
        if client.auth.currentUser?.isAnonymous == true {
            _ = try await client.auth.linkIdentityWithIdToken(credentials: credentials)
        } else {
            _ = try await client.auth.signInWithIdToken(credentials: credentials)
        }
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }
}
