import SwiftUI

struct RootView: View {
    @StateObject private var v2ViewModel = RoundSessionViewModel()
    @StateObject private var legacyViewModel = InterviewViewModel()
    @StateObject private var authViewModel = AuthViewModel()
    @State private var resumableLegacySession: SessionDetail?
    @State private var isResumingLegacy = false
    @State private var selectedTab: Tab = .practice

    private let dataService = SupabaseDataService()

    private enum Tab { case practice, plans, history, profile }

    var body: some View {
        Group {
            if isResumingLegacy {
                NavigationStack { legacyContent }
            } else {
                TabView(selection: $selectedTab) {
                    NavigationStack {
                        RoundSessionFlowView(viewModel: v2ViewModel)
                            .toolbar(.hidden, for: .navigationBar)
                    }
                    .tabItem { Label("Practice", systemImage: "flame.fill") }
                    .tag(Tab.practice)

                    PlansView { plan, stage in
                        v2ViewModel.startPlanStage(plan: plan, stage: stage)
                        selectedTab = .practice
                    }
                    .tabItem { Label("Plans", systemImage: "checklist") }
                    .tag(Tab.plans)

                    HistoryView()
                        .tabItem { Label("History", systemImage: "clock") }
                        .tag(Tab.history)

                    AuthView(viewModel: authViewModel, isModal: false)
                        .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                        .tag(Tab.profile)
                }
                .tint(DesignTokens.accentStrong)
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
