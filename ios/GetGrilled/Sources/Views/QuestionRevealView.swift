import SwiftUI

/// Full-screen "entering the call" moment before the candidate starts responding.
struct QuestionRevealView: View {
    @ObservedObject var viewModel: RoundSessionViewModel

    var body: some View {
        VStack(spacing: 24) {
            if let round = viewModel.currentRound {
                VStack(spacing: 4) {
                    Text(round.type.displayName.uppercased())
                        .font(.onest(12, .bold))
                        .foregroundStyle(DesignTokens.accentStrong)
                    Text("Round \(round.order + 1) of \(viewModel.totalRounds)")
                        .font(.onest(12))
                        .foregroundStyle(DesignTokens.inkSoft)
                }
                roundProgress(currentOrder: round.order)
            }

            Spacer()

            VStack(spacing: 14) {
                InterviewerPortraitView()
                    .frame(width: 148, height: 148)
                Text("Alex · your interviewer").font(.onest(12, .semibold)).foregroundStyle(DesignTokens.inkSoft)

                if let question = viewModel.messages.last {
                    Text(question.content.isEmpty ? "…" : question.content)
                        .font(.onest(16))
                        .foregroundStyle(DesignTokens.ink)
                        .padding(16)
                        .background(DesignTokens.surface, in: RoundedRectangle(cornerRadius: 16))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Spacer()

            Button {
                viewModel.proceedToRound()
            } label: {
                Text("I'm ready to answer →")
                    .font(.onest(15, .bold))
                    .foregroundStyle(DesignTokens.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignTokens.accent)
            .disabled(viewModel.isStreaming)
        }
        .padding()
        .background(DesignTokens.bg.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func roundProgress(currentOrder: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<viewModel.totalRounds, id: \.self) { index in
                Capsule()
                    .fill(index < currentOrder ? DesignTokens.success : (index == currentOrder ? DesignTokens.accent : DesignTokens.line))
                    .frame(height: 5)
            }
        }
    }
}

#Preview {
    NavigationStack {
        QuestionRevealView(viewModel: RoundSessionViewModel())
    }
}
