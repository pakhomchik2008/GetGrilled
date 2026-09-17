import SwiftUI

/// Full-screen "entering the call" moment before the candidate starts responding.
struct QuestionRevealView: View {
    @ObservedObject var viewModel: RoundSessionViewModel

    var body: some View {
        VStack(spacing: 0) {
            if let round = viewModel.currentRound {
                VStack(spacing: 10) {
                    HStack {
                        Text(round.type.displayName.uppercased())
                            .font(.onest(11.5, .bold))
                            .tracking(0.4)
                            .foregroundStyle(DesignTokens.accentStrong)
                        Spacer()
                        Text("Round \(round.order + 1) of \(viewModel.totalRounds)")
                            .font(.onest(11.5))
                            .foregroundStyle(DesignTokens.inkFaint)
                    }
                    RoundProgressBar(total: viewModel.totalRounds, currentOrder: round.order)
                }
                .padding(.bottom, 28)
            }

            Spacer()

            VStack(spacing: 16) {
                InterviewerPortraitView()
                    .frame(width: 168, height: 168)
                    .clipShape(RoundedRectangle(cornerRadius: 44))
                    .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
                Text("Alex · your interviewer").font(.onest(13, .semibold)).foregroundStyle(DesignTokens.inkFaint)

                if let question = viewModel.messages.last {
                    // Plain text while streaming in — see RoundView's callStage for why.
                    Group {
                        if viewModel.isStreaming {
                            Text(question.content.isEmpty ? "…" : question.content)
                                .font(.onest(16))
                                .foregroundStyle(DesignTokens.ink)
                        } else {
                            MarkdownText(content: question.content.isEmpty ? "…" : question.content, size: 16, color: DesignTokens.ink)
                        }
                    }
                        .lineSpacing(4)
                        .padding(18)
                        .padding(.trailing, 20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DesignTokens.surfaceSunken, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(DesignTokens.line, lineWidth: 1))
                        .overlay(alignment: .topTrailing) {
                            NarratorSpeakerButton(narrator: viewModel.narrator).padding(10)
                        }
                }
            }

            Spacer()

            Button {
                viewModel.proceedToRound()
            } label: {
                Text("I'm ready to answer →")
            }
            .buttonStyle(.ggPrimary)
            .disabled(viewModel.isStreaming)
        }
        .padding(20)
        .background(DesignTokens.bg.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.limitReached) { PaywallView() }
    }
}

#Preview {
    NavigationStack {
        QuestionRevealView(viewModel: RoundSessionViewModel())
    }
}
