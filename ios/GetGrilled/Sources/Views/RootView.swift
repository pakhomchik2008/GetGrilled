import SwiftUI

struct RootView: View {
    @StateObject private var viewModel = InterviewViewModel()
    @StateObject private var authViewModel = AuthViewModel()
    @State private var showingAccount = false
    @State private var showingHistory = false
    @State private var resumableSession: SessionDetail?

    private let dataService = SupabaseDataService()

    var body: some View {
        NavigationStack {
            content
                .toolbar {
                    if viewModel.phase == .selectingDifficulty {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("History") { showingHistory = true }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Account") { showingAccount = true }
                        }
                    }
                }
        }
        .sheet(isPresented: $showingAccount) { AuthView(viewModel: authViewModel) }
        .sheet(isPresented: $showingHistory) { HistoryView() }
        .task { await checkForResumableSession() }
        .alert("Resume interview?", isPresented: Binding(
            get: { resumableSession != nil },
            set: { if !$0 { resumableSession = nil } }
        )) {
            Button("Resume") {
                if let resumableSession { viewModel.resume(from: resumableSession) }
                resumableSession = nil
            }
            Button("Start New", role: .cancel) { resumableSession = nil }
        } message: {
            Text("You have an unfinished \(resumableSession?.difficulty.displayName.lowercased() ?? "") interview.")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .selectingDifficulty:
            DifficultySelectionView(viewModel: viewModel)
        case .interviewing, .evaluating:
            InterviewChatView(viewModel: viewModel)
                .overlay {
                    if viewModel.phase == .evaluating {
                        ProgressView("Evaluating…")
                            .padding()
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
        case .showingFeedback:
            if let feedback = viewModel.feedback {
                FeedbackView(feedback: feedback)
            }
        }
    }

    private func checkForResumableSession() async {
        guard viewModel.phase == .selectingDifficulty else { return }
        resumableSession = try? await dataService.latestResumableSession()
    }
}

#Preview {
    RootView()
}
