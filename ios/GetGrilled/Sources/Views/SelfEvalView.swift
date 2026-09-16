import SwiftUI

struct SelfEvalView: View {
    @ObservedObject var viewModel: RoundSessionViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("\(viewModel.currentRound?.type.displayName ?? "") round · done")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text("How do you think that went?")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text("Rate yourself before you see the interviewer's take — that gap is the useful part.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 10) {
                ForEach(SelfEval.allCases) { option in
                    Button {
                        viewModel.selfEvalChoice = option
                    } label: {
                        Text(option.displayName)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                viewModel.selfEvalChoice == option ? Color.accentColor : Color(.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                            .foregroundStyle(viewModel.selfEvalChoice == option ? .white : .primary)
                    }
                }
            }

            Spacer()

            Button {
                viewModel.confirmSelfEval()
            } label: {
                Text("See interviewer's feedback").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.selfEvalChoice == nil)
        }
        .padding()
    }
}

#Preview {
    SelfEvalView(viewModel: RoundSessionViewModel())
}
