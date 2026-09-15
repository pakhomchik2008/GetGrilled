import SwiftUI

struct DifficultySelectionView: View {
    @ObservedObject var viewModel: InterviewViewModel
    @State private var selected: Difficulty = .medium

    var body: some View {
        VStack(spacing: 24) {
            Text("Pick a difficulty")
                .font(.title2.bold())

            Picker("Difficulty", selection: $selected) {
                ForEach(Difficulty.allCases) { difficulty in
                    Text(difficulty.displayName).tag(difficulty)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Button {
                viewModel.start(difficulty: selected)
            } label: {
                Text("Start interview")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
        }
        .padding()
    }
}

#Preview {
    DifficultySelectionView(viewModel: InterviewViewModel())
}
