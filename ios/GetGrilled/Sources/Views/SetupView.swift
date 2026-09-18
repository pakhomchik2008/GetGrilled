import SwiftUI
import UniformTypeIdentifiers

struct SetupView: View {
    private enum JobMethod: Equatable { case pdf, link, text }

    @ObservedObject var viewModel: RoundSessionViewModel
    @State private var jobLinkText = ""
    @State private var showingPDFPicker = false
    @State private var pastedJobText = ""
    @State private var selectedMethod: JobMethod?

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

                jobPostingSection

                Button {
                    viewModel.startManualSession()
                } label: {
                    Text("Start interview")
                }
                .buttonStyle(.ggPrimary)
                .disabled(
                    viewModel.roleTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || viewModel.jobContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )

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
        .fileImporter(isPresented: $showingPDFPicker, allowedContentTypes: [.pdf]) { result in
            switch result {
            case .success(let url):
                loadPDF(from: url)
            case .failure(let error):
                viewModel.jobContextError = "Couldn't open that file: \(error.localizedDescription)"
            }
        }
    }

    private func loadPDF(from url: URL) {
        let gotAccess = url.startAccessingSecurityScopedResource()
        defer { if gotAccess { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            viewModel.attachJobPDF(data: data, filename: url.lastPathComponent)
        } catch {
            viewModel.jobContextError = "Couldn't read that file: \(error.localizedDescription)"
        }
    }

    private var jobPostingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel("About the role")
            Text("Pick one — the interviewer tailors its questions to the real job instead of guessing.")
                .font(.onest(11.5))
                .foregroundStyle(DesignTokens.inkFaint)

            if let label = viewModel.jobContextSourceLabel {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.fill").foregroundStyle(DesignTokens.success)
                    Text(label).font(.onest(13)).foregroundStyle(DesignTokens.ink).lineLimit(1)
                    Spacer()
                    Button {
                        viewModel.clearJobContext()
                        selectedMethod = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(DesignTokens.inkFaint)
                    }
                }
                .fakeFieldStyle()
            } else {
                VStack(spacing: 8) {
                    methodCard(
                        method: .pdf,
                        icon: "doc.badge.plus",
                        title: "PDF of the posting",
                        subtitle: "Attach a file from Files"
                    ) {
                        selectedMethod = .pdf
                        showingPDFPicker = true
                    }
                    methodCard(
                        method: .link,
                        icon: "link",
                        title: "Link to the posting",
                        subtitle: "LinkedIn, HH, Greenhouse, etc."
                    ) {
                        selectedMethod = .link
                    }
                    methodCard(
                        method: .text,
                        icon: "square.and.pencil",
                        title: "Describe it yourself",
                        subtitle: "Type the role's key details"
                    ) {
                        selectedMethod = .text
                    }
                }

                if viewModel.isExtractingJobContext {
                    HStack(spacing: 6) {
                        ProgressView()
                        Text("Reading…").font(.onest(11)).foregroundStyle(DesignTokens.inkFaint)
                    }
                }

                if selectedMethod == .link {
                    HStack(spacing: 8) {
                        TextField("Paste job link…", text: $jobLinkText)
                            .textFieldStyle(.plain)
                            .font(.onest(13))
                            .fakeFieldStyle()
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.go)
                            .onSubmit {
                                viewModel.attachJobLink(jobLinkText)
                            }
                        Button("Go") { viewModel.attachJobLink(jobLinkText) }
                            .font(.onest(13, .semibold))
                            .foregroundStyle(DesignTokens.accentStrong)
                            .disabled(jobLinkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                if selectedMethod == .text {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Type the role's stack, responsibilities, level…", text: $pastedJobText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.onest(13))
                            .lineLimit(4...10)
                            .fakeFieldStyle()
                        Button("Attach this text") {
                            viewModel.attachJobText(pastedJobText)
                            pastedJobText = ""
                        }
                        .font(.onest(12, .semibold))
                        .foregroundStyle(DesignTokens.accentStrong)
                        .disabled(pastedJobText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }

            if let jobContextError = viewModel.jobContextError {
                Text(jobContextError).font(.onest(11)).foregroundStyle(DesignTokens.danger)
            }
        }
    }

    private func methodCard(method: JobMethod, icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        let isSelected = selectedMethod == method
        return Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? DesignTokens.onAccent : DesignTokens.accentStrong)
                    .frame(width: 38, height: 38)
                    .background(isSelected ? DesignTokens.accent : DesignTokens.accentWash, in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.onest(13.5, .semibold)).foregroundStyle(DesignTokens.ink)
                    Text(subtitle).font(.onest(11)).foregroundStyle(DesignTokens.inkFaint)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? DesignTokens.accentStrong : DesignTokens.line)
            }
            .padding(12)
            .background(isSelected ? DesignTokens.accentWash : DesignTokens.surface, in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(isSelected ? DesignTokens.accentStrong : DesignTokens.line, lineWidth: isSelected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SetupView(viewModel: RoundSessionViewModel())
}
