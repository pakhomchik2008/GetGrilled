import SwiftUI

struct RootView: View {
    @StateObject private var v2ViewModel = RoundSessionViewModel()
    @StateObject private var legacyViewModel = InterviewViewModel()
    @StateObject private var authViewModel = AuthViewModel()
    @State private var showingAccount = false
    @State private var showingHistory = false
    @State private var showingPlans = false
    @State private var showingPaywall = false
    @State private var resumableLegacySession: SessionDetail?
    @State private var isResumingLegacy = false

    private let dataService = SupabaseDataService()

    var body: some View {
        NavigationStack {
            content
                .toolbar {
                    if !isResumingLegacy && v2ViewModel.phase == .setup {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Plans") { showingPlans = true }
                        }
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("History") { showingHistory = true }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Upgrade") { showingPaywall = true }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Account") { showingAccount = true }
                        }
                    }
                }
        }
        .sheet(isPresented: $showingAccount) { AuthView(viewModel: authViewModel) }
        .sheet(isPresented: $showingHistory) { HistoryView() }
        .sheet(isPresented: $showingPaywall) { PaywallView() }
        .sheet(isPresented: $showingPlans) {
            PlansView { plan, stage in
                v2ViewModel.startPlanStage(plan: plan, stage: stage)
            }
        }
        .task { await checkForResumableLegacySession() }
        .alert("Resume interview?", isPresented: Binding(
            get: { resumableLegacySession != nil },
            set: { if !$0 { resumableLegacySession = nil } }
        )) {
            Button("Resume") {
                if let resumableLegacySession {
                    legacyViewModel.resume(from: resumableLegacySession)
                    isResumingLegacy = true
                }
                resumableLegacySession = nil
            }
            Button("Start New", role: .cancel) { resumableLegacySession = nil }
        } message: {
            Text("You have an unfinished \(resumableLegacySession?.difficulty.displayName.lowercased() ?? "") interview from before the app's redesign.")
        }
    }

    @ViewBuilder
    private var content: some View {
        if isResumingLegacy {
            legacyContent
        } else {
            RoundSessionFlowView(viewModel: v2ViewModel)
        }
    }

    @ViewBuilder
    private var legacyContent: some View {
        switch legacyViewModel.phase {
        case .selectingDifficulty:
            DifficultySelectionView(viewModel: legacyViewModel)
        case .interviewing, .evaluating:
            InterviewChatView(viewModel: legacyViewModel)
                .overlay {
                    if legacyViewModel.phase == .evaluating {
                        ProgressView("Evaluating…")
                            .padding()
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
        case .showingFeedback:
            if let feedback = legacyViewModel.feedback {
                FeedbackView(feedback: feedback)
            }
        }
    }

    private func checkForResumableLegacySession() async {
        guard v2ViewModel.phase == .setup, !isResumingLegacy else { return }
        resumableLegacySession = try? await dataService.latestResumableSession()
    }
}

#Preview {
    RootView()
}
