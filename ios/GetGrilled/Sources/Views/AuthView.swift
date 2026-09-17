import AuthenticationServices
import SwiftUI

struct AuthView: View {
    @ObservedObject var viewModel: AuthViewModel
    @ObservedObject private var purchases = PurchasesService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .signIn
    @State private var showingPaywall = false
    @State private var debugMessage: String?
    @State private var isDebugWorking = false
    private let api = RoundAPIClient()
    /// Set when presented as a modal sheet (from a screen without its own tab bar); a plain
    /// tab-bar destination shows no "Close" button.
    var isModal: Bool = true

    private enum Mode: String, CaseIterable {
        case signIn = "Sign In"
        case signUp = "Sign Up"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !isModal {
                        Text("Profile")
                            .font(.onest(22, .bold))
                            .foregroundStyle(DesignTokens.ink)
                    }

                    if let user = viewModel.currentUser, !viewModel.isAnonymous {
                        signedInView(email: user.email ?? "")
                    } else {
                        signedOutForm
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.onest(12))
                            .foregroundStyle(DesignTokens.danger)
                    }

                    if !purchases.isPro {
                        upsellCard
                    }

                    debugSection
                }
                .padding(20)
            }
            .background(DesignTokens.bg.ignoresSafeArea())
            .toolbar(isModal ? .automatic : .hidden, for: .navigationBar)
            .navigationTitle(isModal ? "Account" : "")
            .toolbar {
                if isModal {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
            }
            .sheet(isPresented: $showingPaywall) { PaywallView() }
        }
    }

    private var upsellCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FREE TIER").font(.onest(12, .bold)).tracking(0.4).foregroundStyle(DesignTokens.accentStrong)
            Text("You're on the free plan").font(.onest(16, .bold)).foregroundStyle(DesignTokens.ink)
            Text("3 Test sessions and 2 Competition sessions per week. Upgrade for unlimited.")
                .font(.onest(12.5))
                .foregroundStyle(DesignTokens.inkSoft)
            Button("See pricing") { showingPaywall = true }
                .buttonStyle(.ggPrimary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(DesignTokens.surfaceSunken, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(DesignTokens.line, lineWidth: 1))
    }

    /// Bypasses the weekly free-session limit for whichever account is signed in on this device
    /// (anonymous included) — this is what checkWeeklyLimit actually reads server-side, unlike
    /// `purchases.isPro` above which only reflects RevenueCat and won't move until that's
    /// configured. TODO: remove this whole section (and grant-unlimited.ts) before App Store
    /// submission — RevenueCat is the real gate.
    private var debugSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DEBUG").font(.onest(11, .bold)).tracking(0.4).foregroundStyle(DesignTokens.danger)
            Text("Bypasses weekly session limits for testing. Remove before shipping.")
                .font(.onest(11))
                .foregroundStyle(DesignTokens.inkFaint)
            HStack(spacing: 8) {
                Button("Unlock unlimited") { setDebugSubscription(paid: true) }
                    .buttonStyle(.ggSecondary)
                Button("Reset to free") { setDebugSubscription(paid: false) }
                    .buttonStyle(.ggSecondary)
            }
            if isDebugWorking {
                ProgressView()
            }
            if let debugMessage {
                Text(debugMessage).font(.onest(11)).foregroundStyle(DesignTokens.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(DesignTokens.dangerWash, in: RoundedRectangle(cornerRadius: 12))
    }

    private func setDebugSubscription(paid: Bool) {
        isDebugWorking = true
        debugMessage = nil
        Task {
            defer { isDebugWorking = false }
            do {
                let result = try await api.debugSetSubscription(paid: paid)
                debugMessage = "Backend subscriptionStatus = \(result.subscriptionStatus)"
            } catch {
                debugMessage = "Failed: \(error.localizedDescription)"
            }
        }
    }

    private func signedInView(email: String) -> some View {
        VStack(spacing: 16) {
            Text("Signed in as").font(.onest(13)).foregroundStyle(DesignTokens.inkSoft)
            Text(email).font(.onest(16, .semibold)).foregroundStyle(DesignTokens.ink)
            Button("Sign Out", role: .destructive) { viewModel.signOut() }
                .font(.onest(14, .semibold))
        }
    }

    private var signedOutForm: some View {
        VStack(spacing: 14) {
            SegmentedControl(options: Mode.allCases, label: \.rawValue, selection: $mode)

            TextField("Email", text: $viewModel.email)
                .textFieldStyle(.plain)
                .fakeFieldStyle()
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            SecureField("Password", text: $viewModel.password)
                .textFieldStyle(.plain)
                .fakeFieldStyle()

            Button(mode.rawValue) {
                mode == .signIn ? viewModel.signIn() : viewModel.signUp()
            }
            .buttonStyle(.ggPrimary)
            .disabled(viewModel.isLoading || viewModel.email.isEmpty || viewModel.password.isEmpty)

            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.email]
                request.nonce = viewModel.prepareAppleRequestNonce()
            } onCompletion: { result in
                viewModel.handleAppleCompletion(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if viewModel.isLoading {
                ProgressView()
            }
        }
    }
}

#Preview {
    AuthView(viewModel: AuthViewModel())
}
