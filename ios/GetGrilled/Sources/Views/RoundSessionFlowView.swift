import SwiftUI

/// Routes through the v2 round-based interview flow: Setup → Question → Round →
/// (Self-eval, Test mode only) → repeat per round → Summary.
struct RoundSessionFlowView: View {
    @ObservedObject var viewModel: RoundSessionViewModel

    var body: some View {
        content
            .overlay {
                if viewModel.phase == .evaluatingRound {
                    ProgressView("Evaluating…")
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .setup:
            SetupView(viewModel: viewModel)
        case .question:
            QuestionRevealView(viewModel: viewModel)
        case .round, .evaluatingRound:
            RoundView(viewModel: viewModel)
        case .selfEval:
            SelfEvalView(viewModel: viewModel)
        case .summary:
            SessionSummaryView(
                roleTitle: viewModel.roleTitle,
                seniority: viewModel.seniority,
                mode: viewModel.mode,
                rounds: viewModel.roundSummaries,
                overallSummary: viewModel.overallSummary ?? "",
                onBackToDashboard: { viewModel.resetToSetup() }
            )
        }
    }
}

#Preview {
    NavigationStack {
        RoundSessionFlowView(viewModel: RoundSessionViewModel())
    }
}
