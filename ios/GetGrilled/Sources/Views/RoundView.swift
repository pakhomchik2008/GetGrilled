import PhotosUI
import SwiftUI

struct RoundView: View {
    @ObservedObject var viewModel: RoundSessionViewModel
    @StateObject private var camera = CameraMirrorService()
    @State private var isCameraOn = false
    @State private var photoItem: PhotosPickerItem?

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
                    }

                    HStack(spacing: 6) {
                        ChipButton(title: "🤔 Not sure", action: { viewModel.sendChip(.hint) }, disabled: viewModel.isStreaming)
                        ChipButton(title: "↻ Repeat question", action: { viewModel.sendChip(.repeatQuestion) }, disabled: viewModel.isStreaming)
                        ChipButton(title: "⏭ Skip round", action: { viewModel.skipRound() }, disabled: viewModel.isStreaming)
                        Spacer(minLength: 0)
                    }

                    if viewModel.currentRound?.type.usesCodeEditor == true {
                        codeEditorBlock
                    }

                    if let pendingImage = viewModel.pendingImage {
                        attachedImagePreview(pendingImage)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
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
            }
            if let voiceError = viewModel.voiceInputErrorMessage {
                Text(voiceError).font(.onest(12)).foregroundStyle(DesignTokens.warn).padding(.horizontal)
            }
        }
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
                    Text(message.content.isEmpty ? "…" : message.content)
                        .font(.onest(14.5))
                        .foregroundStyle(DesignTokens.ink)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .padding(.trailing, 18)
                        .background(DesignTokens.surface, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(DesignTokens.line, lineWidth: 1))
                        .overlay(alignment: .topTrailing) {
                            NarratorSpeakerButton(narrator: viewModel.narrator).padding(8)
                        }
                }
            }
            .padding(.top, 22)
            .padding(.horizontal, 16)
            .padding(.bottom, 18)

            cameraCorner.padding(10)
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

            TextField("Hold to talk, or type…", text: $viewModel.explanationText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.onest(14))
                .foregroundStyle(DesignTokens.ink)
                .lineLimit(1...4)
                .padding(.horizontal, 8)

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
        .disabled(viewModel.isStreaming)
    }

    private var micButton: some View {
        Image(systemName: viewModel.speechRecognizer.isRecording ? "mic.fill" : "mic")
            .font(.system(size: 14))
            .foregroundStyle(DesignTokens.onAccent)
            .frame(width: 34, height: 34)
            .background(viewModel.speechRecognizer.isRecording ? DesignTokens.danger : DesignTokens.accent, in: Circle())
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                if pressing {
                    viewModel.startVoiceInput()
                } else {
                    viewModel.stopVoiceInput()
                }
            }, perform: {})
            .opacity(viewModel.isStreaming ? 0.5 : 1)
            .allowsHitTesting(!viewModel.isStreaming)
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
