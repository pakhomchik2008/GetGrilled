import SwiftUI

struct RootView: View {
    @StateObject private var viewModel = InterviewViewModel()

    var body: some View {
        NavigationStack {
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
    }
}

#Preview {
    RootView()
}
