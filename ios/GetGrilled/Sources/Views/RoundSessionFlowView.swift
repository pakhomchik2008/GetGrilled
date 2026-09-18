import SwiftUI

/// Routes through the v2 round-based interview flow: Setup → Question → Round →
/// (Self-eval, Test mode only) → repeat per round → Summary.
struct RoundSessionFlowView: View {
    @ObservedObject var viewModel: RoundSessionViewModel
    @State private var showingExitConfirm = false

    private var showsExitButton: Bool {
        switch viewModel.phase {
        case .question, .round, .selfEval, .evaluatingRound: return true
        case .setup, .jobContext, .summary: return false
        }
    }

    var body: some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                if showsExitButton {
                    HStack {
                        Button {
                            showingExitConfirm = true
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(DesignTokens.inkSoft)
                                .frame(width: 30, height: 30)
                                .background(.thinMaterial, in: Circle())
                                .overlay(Circle().stroke(DesignTokens.line, lineWidth: 1))
                        }
                        Spacer()
                    }
                    .padding(.leading, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 2)
                }
            }
            .overlay {
                if viewModel.phase == .evaluatingRound {
                    ProgressView("Evaluating…")
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .confirmationDialog(
                "Leave this interview?",
                isPresented: $showingExitConfirm,
                titleVisibility: .visible
            ) {
                Button("Leave and go home", role: .destructive) { viewModel.resetToSetup() }
                Button("Keep going", role: .cancel) {}
            } message: {
                Text("Your progress in this round won't be saved.")
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .setup:
            SetupView(viewModel: viewModel)
        case .jobContext:
            JobContextPickerView(viewModel: viewModel)
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
