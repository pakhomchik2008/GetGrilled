import SwiftUI

struct InterviewChatView: View {
    @ObservedObject var viewModel: InterviewViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.last?.content) { _ in
                    if let lastId = viewModel.messages.last?.id {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }

            Divider()

            VStack(spacing: 8) {
                Picker("Language", selection: $viewModel.language) {
                    ForEach(CodeLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.segmented)

                CodeEditorView(text: $viewModel.codeText, language: viewModel.language)
                    .frame(height: 160)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(UIColor.separator)))

                TextField("Explain your approach...", text: $viewModel.explanationText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)

                HStack {
                    Button("I'm done") { viewModel.finish() }
                        .disabled(viewModel.isStreaming)
                    Spacer()
                    Button("Send") { viewModel.send() }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isStreaming)
                }
            }
            .padding()

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
        }
        .navigationTitle("Interview")
    }

    private func messageBubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.role == .candidate { Spacer(minLength: 40) }
            Text(message.content.isEmpty ? "…" : message.content)
                .padding(10)
                .background(message.role == .interviewer ? Color(.secondarySystemBackground) : Color.accentColor.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            if message.role == .interviewer { Spacer(minLength: 40) }
        }
    }
}

#Preview {
    NavigationStack {
        InterviewChatView(viewModel: InterviewViewModel())
    }
}
