import PhotosUI
import SwiftUI

struct RoundView: View {
    @ObservedObject var viewModel: RoundSessionViewModel
    // Observed separately from `viewModel` so live partial-transcript updates while recording
    // (which don't touch any of RoundSessionViewModel's own @Published properties) still
    // trigger a redraw here.
    @ObservedObject var speechRecognizer: SpeechRecognizer
    @StateObject private var camera = CameraMirrorService()
    @State private var isCameraOn = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isMicPressed = false
    @State private var micPulse = false

    init(viewModel: RoundSessionViewModel) {
        self.viewModel = viewModel
        self.speechRecognizer = viewModel.speechRecognizer
    }

    private var lastInterviewerMessage: ChatMessage? {
        viewModel.messages.last(where: { $0.role == .interviewer })
    }

    /// Only shown while it's the most recent thing said — once the interviewer replies again
    /// it drops off, same "live call" feel as the approved design mockup.
    private var liveCandidateReply: ChatMessage? {
        guard let last = viewModel.messages.last, last.role == .candidate else { return nil }
        return last
    }

    var body: some View {
        VStack(spacing: 0) {
            if let round = viewModel.currentRound {
                VStack(spacing: 8) {
                    HStack {
                        Text(round.type.displayName.uppercased())
                            .font(.onest(11.5, .bold))
                            .tracking(0.4)
                            .foregroundStyle(DesignTokens.accentStrong)
                        Spacer()
                        Text("Round \(round.order + 1) of \(viewModel.totalRounds)")
                            .font(.onest(11.5))
                            .foregroundStyle(DesignTokens.inkFaint)
                    }
                    RoundProgressBar(total: viewModel.totalRounds, currentOrder: round.order)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 4)
            }

            ScrollView {
                VStack(spacing: 14) {
                    callStage

                    if let liveCandidateReply {
                        HStack {
                            Spacer(minLength: 40)
                            Text(liveCandidateReply.content)
                                .font(.onest(14))
                                .foregroundStyle(DesignTokens.ink)
                                .padding(11)
                                .background(DesignTokens.accentWash, in: RoundedRectangle(cornerRadius: 14))
                        }
                        // Arrives from below like a sent chat bubble — same path it'll take
                        // out when the interviewer's next reply pushes it off (spatial consistency).
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .id(liveCandidateReply.id)
                    }

                    HStack(spacing: 6) {
                        ChipButton(title: "🤔 Not sure", action: { viewModel.sendChip(.hint) }, disabled: viewModel.isStreaming)
                        ChipButton(title: "↻ Repeat question", action: { viewModel.sendChip(.repeatQuestion) }, disabled: viewModel.isStreaming)
                        ChipButton(title: "⏭ Skip round", action: { viewModel.skipRound() }, disabled: viewModel.isStreaming)
                        Spacer(minLength: 0)
                    }

                    if viewModel.currentRound?.type.usesCodeEditor == true {
                        codeEditorBlock
                            .transition(MotionTokens.materialize)
                    }

                    if let pendingImage = viewModel.pendingImage {
                        attachedImagePreview(pendingImage)
                            .transition(MotionTokens.materialize)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .animation(MotionTokens.standard, value: viewModel.messages.map(\.id))
                .animation(MotionTokens.standard, value: viewModel.currentRound?.type.usesCodeEditor)
                .animation(MotionTokens.standard, value: viewModel.pendingImage != nil)
            }

            Divider()

            VStack(spacing: 10) {
                inputRow

                HStack {
                    Button("I'm done") { viewModel.finishRoundTapped() }
                        .font(.onest(13, .semibold))
                        .foregroundStyle(DesignTokens.inkSoft)
                        .disabled(viewModel.isStreaming)
                    Spacer()
                }
            }
            .padding()

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage).font(.onest(12)).foregroundStyle(DesignTokens.danger).padding(.horizontal)
                    .transition(.opacity)
            }
            if let voiceError = viewModel.voiceInputErrorMessage {
                Text(voiceError).font(.onest(12)).foregroundStyle(DesignTokens.warn).padding(.horizontal)
                    .transition(.opacity)
            }
        }
        .animation(MotionTokens.standard, value: viewModel.errorMessage)
        .animation(MotionTokens.standard, value: viewModel.voiceInputErrorMessage)
        .background(DesignTokens.bg.ignoresSafeArea())
        .navigationTitle(viewModel.currentRound?.type.displayName ?? "Round")
        .onDisappear { camera.stop() }
    }

    // MARK: Call stage

    private var callStage: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(colors: [DesignTokens.accentWash, DesignTokens.surfaceSunken], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(DesignTokens.line, lineWidth: 1))

            VStack(spacing: 8) {
                InterviewerPortraitView()
                    .frame(width: 76, height: 76)
                    .background(DesignTokens.surface, in: RoundedRectangle(cornerRadius: 22))
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                Text("Alex · your interviewer").font(.onest(12, .semibold)).foregroundStyle(DesignTokens.inkFaint)

                if let message = lastInterviewerMessage {
                    // Plain text while this message is still streaming in — parsing partial
                    // Markdown mid-token can swallow a delimiter's characters before its pair
                    // has arrived. Switch to the rich render once the stream settles.
                    Group {
                        if viewModel.isStreaming {
                            Text(message.content.isEmpty ? "…" : message.content)
                                .font(.onest(14.5))
                                .foregroundStyle(DesignTokens.ink)
                        } else {
                            MarkdownText(content: message.content.isEmpty ? "…" : message.content, size: 14.5, color: DesignTokens.ink)
                        }
                    }
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .padding(.trailing, 18)
                        .background(DesignTokens.surface, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(DesignTokens.line, lineWidth: 1))
                        .overlay(alignment: .topTrailing) {
                            NarratorSpeakerButton(narrator: viewModel.narrator).padding(8)
                        }
                        // New question materializes as its own bubble arriving, not a hard
                        // content swap inside the old one.
                        .id(message.id)
                        .transition(MotionTokens.materialize)
                }
            }
            .padding(.top, 22)
            .padding(.horizontal, 16)
            .padding(.bottom, 18)
            .animation(MotionTokens.standard, value: lastInterviewerMessage?.id)

            cameraCorner.padding(10)
                .animation(MotionTokens.standard, value: isCameraOn)
        }
    }

    @ViewBuilder
    private var cameraCorner: some View {
        if isCameraOn {
            ZStack(alignment: .bottom) {
                CameraPreviewView(session: camera.session)
                Text("YOU")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.bottom, 3)
            }
            .frame(width: 54, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(DesignTokens.surface, lineWidth: 2))
            .shadow(color: .black.opacity(0.2), radius: 4)
            .transition(MotionTokens.materialize)
            .onTapGesture { isCameraOn = false; camera.stop() }
        } else {
            Button {
                isCameraOn = true
                camera.start()
            } label: {
                Image(systemName: "video")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignTokens.inkFaint)
                    .frame(width: 28, height: 28)
                    .background(DesignTokens.surface, in: Circle())
                    .overlay(Circle().stroke(DesignTokens.line, lineWidth: 1))
            }
            .buttonStyle(IconPressStyle())
            .transition(MotionTokens.materialize)
            if let cameraError = camera.errorMessage {
                Text(cameraError).font(.system(size: 8)).foregroundStyle(.orange).frame(width: 60)
            }
        }
    }

    // MARK: Code editor

    private var codeEditorBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            SegmentedControl(options: CodeLanguage.allCases, label: \.displayName, selection: Binding(
                get: { viewModel.language },
                set: { viewModel.setLanguage($0) }
            ))

            VStack(spacing: 0) {
                HStack {
                    Text("solution.\(viewModel.language == .python ? "py" : "js")")
                        .font(.plexMono(11.5, .medium))
                        .foregroundStyle(DesignTokens.inkFaint)
                    Spacer()
                    Text(viewModel.language.displayName)
                        .font(.onest(10.5, .semibold))
                        .foregroundStyle(DesignTokens.inkFaint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(DesignTokens.surface, in: Capsule())
                        .overlay(Capsule().stroke(DesignTokens.line, lineWidth: 1))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()

                CodeEditorView(text: $viewModel.codeText, language: viewModel.language)
                    .frame(height: 140)
            }
            .background(DesignTokens.codeBg)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(DesignTokens.line, lineWidth: 1))

            Text("Starts as a blank stub — this shows your answer, not a given solution.")
                .font(.onest(11.5))
                .foregroundStyle(DesignTokens.inkFaint)
        }
    }

    // MARK: Input row

    private var inputRow: some View {
        HStack(spacing: 6) {
            attachButton
            pasteButton

            if speechRecognizer.isRecording {
                liveTranscriptPreview
                    .padding(.horizontal, 8)
            } else {
                TextField("Hold to talk, or type…", text: $viewModel.explanationText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.onest(14))
                    .foregroundStyle(DesignTokens.ink)
                    .lineLimit(1...4)
                    .padding(.horizontal, 8)
            }

            micButton
            sendButton
        }
        .padding(4)
        .background(DesignTokens.surfaceSunken, in: Capsule())
        .overlay(Capsule().stroke(DesignTokens.line, lineWidth: 1))
    }

    private var attachButton: some View {
        PhotosPicker(selection: $photoItem, matching: .images) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 15))
                .foregroundStyle(DesignTokens.inkSoft)
                .frame(width: 34, height: 34)
                .background(DesignTokens.surface, in: Circle())
        }
        .buttonStyle(IconPressStyle())
        .onChange(of: photoItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    viewModel.attachImage(image)
                }
                photoItem = nil
            }
        }
        .disabled(viewModel.isStreaming)
    }

    private var pasteButton: some View {
        Button {
            if let image = UIPasteboard.general.image {
                viewModel.attachImage(image)
            }
        } label: {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 15))
                .foregroundStyle(DesignTokens.inkSoft)
                .frame(width: 34, height: 34)
                .background(DesignTokens.surface, in: Circle())
        }
        .buttonStyle(IconPressStyle())
        .disabled(viewModel.isStreaming)
    }

    /// While holding the mic, shows already-typed/committed text in normal ink plus the
    /// in-progress recognized speech in gray — so the candidate can read back what the
    /// recognizer is hearing as they talk, before it commits on release.
    private var liveTranscriptPreview: some View {
        let committed = viewModel.explanationText.trimmingCharacters(in: .whitespacesAndNewlines)
        let partial = speechRecognizer.partialTranscript

        return Group {
            if partial.isEmpty && committed.isEmpty {
                Text("Listening…")
                    .foregroundStyle(DesignTokens.inkFaint)
            } else {
                Text(committed.isEmpty ? "" : committed + " ").foregroundColor(DesignTokens.ink)
                    + Text(partial).foregroundColor(DesignTokens.inkFaint)
            }
        }
        .font(.onest(14))
        .lineLimit(1...4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Hold-to-talk: scales down the instant the finger lands (response starts on press, not
    /// release) and breathes gently while recording — the ongoing-state signal a fixed icon
    /// swap can't give. Both read directly off `isMicPressed`/`isRecording`, never a delayed echo.
    private var micButton: some View {
        Image(systemName: speechRecognizer.isRecording ? "mic.fill" : "mic")
            .font(.system(size: 14))
            .foregroundStyle(DesignTokens.onAccent)
            .frame(width: 34, height: 34)
            .background(speechRecognizer.isRecording ? DesignTokens.danger : DesignTokens.accent, in: Circle())
            .scaleEffect((isMicPressed ? 0.9 : 1) * (micPulse ? 1.1 : 1))
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                withAnimation(MotionTokens.momentum) { isMicPressed = pressing }
                if pressing {
                    viewModel.startVoiceInput()
                } else {
                    viewModel.stopVoiceInput()
                }
            }, perform: {})
            .opacity(viewModel.isStreaming ? 0.5 : 1)
            .allowsHitTesting(!viewModel.isStreaming)
            .onChange(of: speechRecognizer.isRecording) { isRecording in
                if isRecording && !MotionTokens.reduceMotion {
                    withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { micPulse = true }
                } else {
                    withAnimation(MotionTokens.momentum) { micPulse = false }
                }
            }
    }

    private var sendButton: some View {
        Button {
            viewModel.send()
        } label: {
            Image(systemName: "arrow.up")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DesignTokens.surface)
                .frame(width: 34, height: 34)
                .background(DesignTokens.ink, in: Circle())
        }
        .buttonStyle(IconPressStyle())
        .disabled(viewModel.isStreaming)
    }

    private func attachedImagePreview(_ image: UIImage) -> some View {
        HStack(spacing: 8) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text("Screenshot attached")
                .font(.onest(12))
                .foregroundStyle(DesignTokens.inkSoft)
            Spacer()
            Button {
                viewModel.removePendingImage()
            } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(DesignTokens.inkFaint)
            }
        }
        .padding(8)
        .background(DesignTokens.surfaceSunken, in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    NavigationStack {
        RoundView(viewModel: RoundSessionViewModel())
    }
}
