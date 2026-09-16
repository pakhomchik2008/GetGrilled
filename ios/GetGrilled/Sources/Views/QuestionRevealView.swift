import SwiftUI

/// Full-screen "entering the call" moment before the candidate starts responding.
struct QuestionRevealView: View {
    @ObservedObject var viewModel: RoundSessionViewModel

    var body: some View {
        VStack(spacing: 24) {
            if let round = viewModel.currentRound {
                VStack(spacing: 4) {
                    Text(round.type.displayName.uppercased())
                        .font(.caption.bold())
                        .foregroundStyle(Color.accentColor)
                    Text("Round \(round.order + 1) of \(viewModel.totalRounds)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                roundProgress(currentOrder: round.order)
            }

            Spacer()

            VStack(spacing: 14) {
                InterviewerPortraitView()
                    .frame(width: 148, height: 148)
                Text("Alex · your interviewer").font(.caption.bold()).foregroundStyle(.secondary)

                if let question = viewModel.messages.last {
                    Text(question.content.isEmpty ? "…" : question.content)
                        .padding(16)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Spacer()

            Button {
                viewModel.proceedToRound()
            } label: {
                Text("I'm ready to answer →").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isStreaming)
        }
        .padding()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func roundProgress(currentOrder: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<viewModel.totalRounds, id: \.self) { index in
                Capsule()
                    .fill(index < currentOrder ? Color.green : (index == currentOrder ? Color.accentColor : Color(.systemGray4)))
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
