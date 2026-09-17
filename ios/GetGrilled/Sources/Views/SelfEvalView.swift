import SwiftUI

struct SelfEvalView: View {
    @ObservedObject var viewModel: RoundSessionViewModel

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            VStack(spacing: 10) {
                Text("\(viewModel.currentRound?.type.displayName ?? "") round · done")
                    .font(.onest(11.5, .bold))
                    .tracking(0.4)
                    .foregroundStyle(DesignTokens.inkFaint)
                Text("How do you think that went?")
                    .font(.onest(22, .extrabold))
                    .foregroundStyle(DesignTokens.ink)
                    .multilineTextAlignment(.center)
                Text("Rate yourself before you see the interviewer's take — that gap is the useful part.")
                    .font(.onest(13.5))
                    .foregroundStyle(DesignTokens.inkSoft)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 8) {
                ForEach(SelfEval.allCases) { option in
                    Button {
                        viewModel.selfEvalChoice = option
                    } label: {
                        Text(option.displayName)
                            .font(.onest(12, .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(viewModel.selfEvalChoice == option ? DesignTokens.onAccent : DesignTokens.inkSoft)
                            .background(
                                viewModel.selfEvalChoice == option ? DesignTokens.accent : DesignTokens.surfaceSunken,
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(viewModel.selfEvalChoice == option ? Color.clear : DesignTokens.line, lineWidth: 1)
                            )
                    }
                }
            }

            Spacer()

            Button {
                viewModel.confirmSelfEval()
            } label: {
                Text("See interviewer's feedback")
            }
            .buttonStyle(.ggPrimary)
            .disabled(viewModel.selfEvalChoice == nil)
        }
        .padding(20)
        .background(DesignTokens.bg.ignoresSafeArea())
    }
}

#Preview {
    SelfEvalView(viewModel: RoundSessionViewModel())
}
