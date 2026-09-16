import SwiftUI

struct RoundView: View {
    @ObservedObject var viewModel: RoundSessionViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            messageBubble(message).id(message.id)
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
                HStack(spacing: 8) {
                    chip("Not sure") { viewModel.sendChip(.hint) }
                    chip("Repeat question") { viewModel.sendChip(.repeatQuestion) }
                    chip("Skip round") { viewModel.skipRound() }
                    Spacer()
                }

                if viewModel.currentRound?.type.usesCodeEditor == true {
                    Picker("Language", selection: Binding(
                        get: { viewModel.language },
                        set: { viewModel.setLanguage($0) }
                    )) {
                        ForEach(CodeLanguage.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    CodeEditorView(text: $viewModel.codeText, language: viewModel.language)
                        .frame(height: 140)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(UIColor.separator)))
                }

                TextField("Explain your approach…", text: $viewModel.explanationText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)

                HStack {
                    Button("I'm done") { viewModel.finishRoundTapped() }
                        .disabled(viewModel.isStreaming)
                    Spacer()
                    Button("Send") { viewModel.send() }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isStreaming)
                }
            }
            .padding()

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.red).padding(.horizontal)
            }
        }
        .navigationTitle(viewModel.currentRound?.type.displayName ?? "Round")
    }

    private func chip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemBackground), in: Capsule())
        }
        .disabled(viewModel.isStreaming)
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
        RoundView(viewModel: RoundSessionViewModel())
    }
}
