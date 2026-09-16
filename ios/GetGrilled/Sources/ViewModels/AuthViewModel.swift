import AuthenticationServices
import CryptoKit
import Foundation
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var currentUser: User?

    /// Set right before presenting the Apple button, verified against the returned id token.
    private(set) var currentAppleNonce: String?

    private let provider = SupabaseAuthProvider.shared
    private var authStateTask: Task<Void, Never>?

    init() {
        authStateTask = Task { [weak self] in
            guard let self else { return }
            for await (_, session) in await self.provider.client.auth.authStateChanges {
                self.currentUser = session?.user
                // Anonymous session ids are stable across the anonymous->permanent upgrade
                // (see SupabaseAuthProvider), so log in from the very first session — this is
                // the same id /api/revenuecat/webhook writes users.subscription_status against.
                if let userId = session?.user.id {
                    // Supabase ids are lowercase UUIDs; Swift's UUID.uuidString is uppercase —
                    // lowercase it so it matches the id verifyAuth() returns on the backend.
                    PurchasesService.shared.logIn(userId: userId.uuidString.lowercased())
                }
            }
        }
    }

    deinit {
        authStateTask?.cancel()
    }

    var isAnonymous: Bool {
        currentUser?.isAnonymous ?? true
    }

    func signUp() {
        run {
            try await self.provider.signUp(email: self.email, password: self.password)
        }
    }

    func signIn() {
        run {
            try await self.provider.signIn(email: self.email, password: self.password)
        }
    }

    func signOut() {
        run {
            try await self.provider.signOut()
        }
    }

    /// Called just before presenting the Apple button, to fill its request's nonce.
    func prepareAppleRequestNonce() -> String {
        let nonce = Self.randomNonceString()
        currentAppleNonce = nonce
        return Self.sha256(nonce)
    }

    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let nonce = currentAppleNonce
            else {
                errorMessage = "Apple sign-in didn't return a usable token."
                return
            }
            run {
                try await self.provider.signInWithApple(idToken: idToken, nonce: nonce)
            }
        }
    }

    private func run(_ operation: @escaping () async throws -> Void) {
        errorMessage = nil
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                try await operation()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private static func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}
