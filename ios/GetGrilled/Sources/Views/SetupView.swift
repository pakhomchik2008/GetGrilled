import SwiftUI

struct SetupView: View {
    @ObservedObject var viewModel: RoundSessionViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text("Before we start")
                        .font(.title2.bold())
                    Text("Tell the interviewer who you're prepping to be.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Mode").font(.caption.bold()).foregroundStyle(.secondary)
                    Picker("Mode", selection: $viewModel.mode) {
                        ForEach(SessionMode.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Role").font(.caption.bold()).foregroundStyle(.secondary)
                    TextField("e.g. Backend Engineer", text: $viewModel.roleTitle)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Level").font(.caption.bold()).foregroundStyle(.secondary)
                    Picker("Level", selection: $viewModel.seniority) {
                        ForEach(Seniority.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Focus on (optional)").font(.caption.bold()).foregroundStyle(.secondary)
                    TextField("Anything you want to work on…", text: $viewModel.focusNotes, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                }

                Button {
                    viewModel.startSession()
                } label: {
                    Text("Start interview").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.roleTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Text("3 rounds · Intro → Technical → Behavioral")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(.red)
                }
            }
            .padding()
        }
    }
}

#Preview {
    SetupView(viewModel: RoundSessionViewModel())
}
