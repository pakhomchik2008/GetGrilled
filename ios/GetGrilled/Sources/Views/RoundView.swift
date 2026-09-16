import SwiftUI

struct RoundView: View {
    @ObservedObject var viewModel: RoundSessionViewModel
    @StateObject private var camera = CameraMirrorService()
    @State private var isCameraOn = false

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            messageBubble(message).id(message.id)
                        }
                    }
                    .padding()
                }
                .overlay(alignment: .topTrailing) {
                    if isCameraOn {
                        CameraPreviewView(session: camera.session)
                            .frame(width: 64, height: 86)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white, lineWidth: 2))
                            .shadow(radius: 4)
                            .padding(10)
                    }
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

                HStack(spacing: 8) {
                    TextField("Explain your approach…", text: $viewModel.explanationText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)

                    micButton
                }

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
            if let voiceError = viewModel.voiceInputErrorMessage {
                Text(voiceError).font(.footnote).foregroundStyle(.orange).padding(.horizontal)
            }
        }
        .background(DesignTokens.bg.ignoresSafeArea())
        .navigationTitle(viewModel.currentRound?.type.displayName ?? "Round")
        .onDisappear { camera.stop() }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    if viewModel.narrator.isSpeaking {
                        viewModel.narrator.stop()
                    } else if viewModel.narrator.isMuted {
                        viewModel.narrator.isMuted = false
                        viewModel.narrator.replay()
                    } else {
                        viewModel.narrator.isMuted = true
                    }
                } label: {
                    Image(systemName: viewModel.narrator.isMuted ? "speaker.slash.fill" : (viewModel.narrator.isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2"))
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            InterviewerPortraitView().frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 0) {
                Text("Alex").font(.onest(13, .semibold)).foregroundStyle(DesignTokens.ink)
                Text("your interviewer").font(.onest(11)).foregroundStyle(DesignTokens.inkSoft)
            }
            Spacer()
            Button {
                isCameraOn.toggle()
                if isCameraOn { camera.start() } else { camera.stop() }
            } label: {
                Image(systemName: isCameraOn ? "video.fill" : "video.slash")
            }
            if let cameraError = camera.errorMessage, isCameraOn {
                Text(cameraError).font(.caption2).foregroundStyle(.orange).lineLimit(1)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var micButton: some View {
        Image(systemName: viewModel.speechRecognizer.isRecording ? "mic.fill" : "mic")
            .font(.system(size: 18))
            .foregroundStyle(viewModel.speechRecognizer.isRecording ? Color.red : Color.accentColor)
            .frame(width: 44, height: 44)
            .background(Color(.secondarySystemBackground), in: Circle())
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                if pressing {
                    viewModel.startVoiceInput()
                } else {
                    viewModel.stopVoiceInput()
                }
            }, perform: {})
            .disabled(viewModel.isStreaming)
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
                .font(.onest(15))
                .foregroundStyle(DesignTokens.ink)
                .padding(10)
                .background(message.role == .interviewer ? DesignTokens.surfaceSunken : DesignTokens.accentWash)
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
