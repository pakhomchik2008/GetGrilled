import SwiftUI
import UniformTypeIdentifiers

struct SetupView: View {
    @ObservedObject var viewModel: RoundSessionViewModel
    @State private var jobLinkText = ""
    @State private var showingPDFPicker = false
    @State private var showingTextPaste = false
    @State private var pastedJobText = ""

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
            FieldLabel("Job posting (optional)")
            Text("Paste the role's job link (LinkedIn, Greenhouse, etc.), attach a PDF, or paste the text — helps tailor questions to the actual role.")
                .font(.onest(11.5))
                .foregroundStyle(DesignTokens.inkFaint)

            if let label = viewModel.jobContextSourceLabel {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.fill").foregroundStyle(DesignTokens.success)
                    Text(label).font(.onest(13)).foregroundStyle(DesignTokens.ink).lineLimit(1)
                    Spacer()
                    Button { viewModel.clearJobContext() } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(DesignTokens.inkFaint)
                    }
                }
                .fakeFieldStyle()
            } else {
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

                    Button {
                        showingPDFPicker = true
                    } label: {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 16))
                            .foregroundStyle(DesignTokens.inkSoft)
                            .frame(width: 44, height: 44)
                            .background(DesignTokens.surface, in: RoundedRectangle(cornerRadius: 11))
                            .overlay(RoundedRectangle(cornerRadius: 11).stroke(DesignTokens.line, lineWidth: 1))
                    }
                }

                if viewModel.isExtractingJobContext {
                    HStack(spacing: 6) {
                        ProgressView()
                        Text("Reading…").font(.onest(11)).foregroundStyle(DesignTokens.inkFaint)
                    }
                }

                if showingTextPaste {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Paste the job description text…", text: $pastedJobText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.onest(13))
                            .lineLimit(4...10)
                            .fakeFieldStyle()
                        Button("Attach this text") {
                            viewModel.attachJobText(pastedJobText)
                            pastedJobText = ""
                            showingTextPaste = false
                        }
                        .font(.onest(12, .semibold))
                        .foregroundStyle(DesignTokens.accentStrong)
                        .disabled(pastedJobText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } else {
                    Button("Or paste the description text instead") { showingTextPaste = true }
                        .font(.onest(11.5))
                        .foregroundStyle(DesignTokens.accentStrong)
                }
            }

            if let jobContextError = viewModel.jobContextError {
                Text(jobContextError).font(.onest(11)).foregroundStyle(DesignTokens.danger)
            }
        }
    }
}

#Preview {
    SetupView(viewModel: RoundSessionViewModel())
}
