import SwiftUI
import UniformTypeIdentifiers

/// Mandatory "how do you want to tell us about the role" step between Setup and the first
/// question — deliberately its own dark screen (not GetGrilled's usual light surface), matching
/// the reference the user approved rather than the rest of the design system.
struct JobContextPickerView: View {
    private enum JobMethod: Equatable { case pdf, link, text }

    @ObservedObject var viewModel: RoundSessionViewModel
    @State private var selectedMethod: JobMethod?
    @State private var jobLinkText = ""
    @State private var pastedJobText = ""
    @State private var showingPDFPicker = false

    private static let gradient = LinearGradient(
        colors: [
            Color(.sRGB, red: 0.165, green: 0.184, blue: 0.431, opacity: 1),
            Color(.sRGB, red: 0.310, green: 0.231, blue: 0.561, opacity: 1),
            Color(.sRGB, red: 0.420, green: 0.247, blue: 0.561, opacity: 1)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private var isFilled: Bool { !viewModel.jobContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    viewModel.backToSetupFields()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.12), in: Circle())
                }
                Spacer()
            }
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 8) {
                Text("About the role")
                    .font(.onest(24, .extrabold))
                    .foregroundStyle(.white)
                Text("One of three ways — required so the questions land.")
                    .font(.onest(13.5))
                    .foregroundStyle(.white.opacity(0.62))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 22)

            VStack(spacing: 12) {
                if let label = viewModel.jobContextSourceLabel {
                    attachedRow(label: label)
                } else {
                    methodCard(method: .pdf, icon: "doc.badge.plus", title: "PDF of the posting", subtitle: "Attach a file from Files") {
                        selectedMethod = .pdf
                        showingPDFPicker = true
                    }
                    methodCard(method: .link, icon: "link", title: "Link to the posting", subtitle: "LinkedIn, HH, Greenhouse, etc.") {
                        selectedMethod = .link
                    }
                    methodCard(method: .text, icon: "square.and.pencil", title: "Describe it yourself", subtitle: "Type the role's key details") {
                        selectedMethod = .text
                    }
                }
            }
            .padding(.top, 22)

            if viewModel.isExtractingJobContext {
                HStack(spacing: 6) {
                    ProgressView().tint(.white)
                    Text("Reading…").font(.onest(12)).foregroundStyle(.white.opacity(0.7))
                }
                .padding(.top, 14)
            }

            if selectedMethod == .link && viewModel.jobContextSourceLabel == nil {
                linkInput.padding(.top, 16)
            }
            if selectedMethod == .text && viewModel.jobContextSourceLabel == nil {
                textInput.padding(.top, 16)
            }

            if let jobContextError = viewModel.jobContextError {
                Text(jobContextError)
                    .font(.onest(12))
                    .foregroundStyle(Color(.sRGB, red: 1, green: 0.6, blue: 0.6, opacity: 1))
                    .padding(.top, 10)
            }

            Spacer(minLength: 12)

            Button {
                viewModel.confirmJobContext()
            } label: {
                if viewModel.isStreaming {
                    ProgressView().tint(Color(.sRGB, red: 0.24, green: 0.18, blue: 0.48, opacity: 1))
                } else {
                    Text("Continue →")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(Color(.sRGB, red: 0.24, green: 0.18, blue: 0.48, opacity: 1))
            .background(isFilled ? .white : .white.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
            .disabled(!isFilled || viewModel.isStreaming)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.onest(12))
                    .foregroundStyle(Color(.sRGB, red: 1, green: 0.6, blue: 0.6, opacity: 1))
                    .padding(.top, 8)
            }
        }
        .padding(20)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Self.gradient.ignoresSafeArea())
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

    private func methodCard(method: JobMethod, icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        let isSelected = selectedMethod == method
        return Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.onest(15.5, .bold)).foregroundStyle(.white)
                    Text(subtitle).font(.onest(12.5)).foregroundStyle(.white.opacity(0.6))
                }

                Spacer(minLength: 0)

                Circle()
                    .fill(isSelected ? Color.white : Color.clear)
                    .overlay(Circle().stroke(.white.opacity(isSelected ? 0 : 0.3), lineWidth: 1.5))
                    .frame(width: 22, height: 22)
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(.sRGB, red: 0.31, green: 0.23, blue: 0.56, opacity: 1))
                        }
                    }
            }
            .padding(16)
            .background(isSelected ? .white.opacity(0.16) : .white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(isSelected ? 0.55 : 0.12), lineWidth: isSelected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }

    private func attachedRow(label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.white)
            Text(label).font(.onest(14)).foregroundStyle(.white).lineLimit(1)
            Spacer()
            Button {
                viewModel.clearJobContext()
                selectedMethod = nil
                jobLinkText = ""
                pastedJobText = ""
            } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(16)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1.5))
    }

    private var linkInput: some View {
        HStack(spacing: 8) {
            TextField("", text: $jobLinkText, prompt: Text("Paste job link…").foregroundColor(.white.opacity(0.4)))
                .textFieldStyle(.plain)
                .font(.onest(13.5))
                .foregroundStyle(.white)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .onSubmit { viewModel.attachJobLink(jobLinkText) }
                .padding(14)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.16), lineWidth: 1))

            Button("Go") { viewModel.attachJobLink(jobLinkText) }
                .font(.onest(13.5, .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
                .disabled(jobLinkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var textInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("", text: $pastedJobText, prompt: Text("Type the role's stack, responsibilities, level…").foregroundColor(.white.opacity(0.4)), axis: .vertical)
                .textFieldStyle(.plain)
                .font(.onest(13.5))
                .foregroundStyle(.white)
                .lineLimit(4...8)
                .padding(14)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.16), lineWidth: 1))

            Button("Attach this text") {
                viewModel.attachJobText(pastedJobText)
                pastedJobText = ""
            }
            .font(.onest(13, .semibold))
            .foregroundStyle(.white)
            .disabled(pastedJobText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

#Preview {
    JobContextPickerView(viewModel: RoundSessionViewModel())
}
