import SwiftUI

struct SetupView: View {
    @ObservedObject var viewModel: RoundSessionViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                HStack(spacing: 7) {
                    Text("🔥").font(.system(size: 16))
                    Text("GetGrilled").font(.onest(14, .bold)).foregroundStyle(DesignTokens.ink)
                }

                VStack(spacing: 6) {
                    Text("Before we start")
                        .font(.onest(25, .extrabold))
                        .foregroundStyle(DesignTokens.ink)
                    Text("Tell the interviewer who you're prepping to be.")
                        .font(.onest(13.5))
                        .foregroundStyle(DesignTokens.inkSoft)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel("Mode")
                    SegmentedControl(options: SessionMode.allCases, label: \.displayName, selection: $viewModel.mode)
                }

                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel("Role")
                    TextField("e.g. Backend Engineer", text: $viewModel.roleTitle)
                        .textFieldStyle(.plain)
                        .fakeFieldStyle()
                }

                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel("Level")
                    SegmentedControl(options: Seniority.allCases, label: \.displayName, selection: $viewModel.seniority)
                }

                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel("Focus on (optional)")
                    TextField("Anything you want to work on…", text: $viewModel.focusNotes, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(2...4)
                        .fakeFieldStyle()
                }

                Button {
                    viewModel.startManualSession()
                } label: {
                    Text("Continue →")
                }
                .buttonStyle(.ggPrimary)
                .disabled(viewModel.roleTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Text("3 rounds · Intro → Technical → Behavioral")
                    .font(.onest(12))
                    .foregroundStyle(DesignTokens.inkFaint)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage).font(.onest(12)).foregroundStyle(DesignTokens.danger)
                }
            }
            .padding(20)
        }
        .background(DesignTokens.bg.ignoresSafeArea())
    }
}

#Preview {
    SetupView(viewModel: RoundSessionViewModel())
}
