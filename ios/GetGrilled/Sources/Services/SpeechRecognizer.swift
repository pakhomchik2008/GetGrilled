import AVFoundation
import Speech

enum SpeechAuthorizationStatus {
    case notDetermined
    case authorized
    case denied
}

/// On-device speech-to-text for push-to-talk answers. Never sends audio off the device —
/// `requiresOnDeviceRecognition` is forced on wherever the platform supports it.
@MainActor
final class SpeechRecognizer: ObservableObject {
    @Published private(set) var isRecording = false
    @Published var errorMessage: String?
    /// Updated live as the recognizer hears words, before the final commit on `stop()` — lets
    /// the UI show a grayed-out "what I'm hearing" preview while the candidate is still talking.
    @Published private(set) var partialTranscript = ""

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var onFinalText: ((String) -> Void)?
    private var pendingTranscriptProvider: (() -> String)?

    func requestAuthorization() async -> SpeechAuthorizationStatus {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else { return .denied }

        let micGranted = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        return micGranted ? .authorized : .denied
    }

    /// Starts recording. `onFinalText` fires once, with the best transcript so far, when `stop()` is called.
    func start(onFinalText: @escaping (String) -> Void) {
        guard !isRecording, let recognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition isn't available right now."
            return
        }
        self.onFinalText = onFinalText
        errorMessage = nil
        partialTranscript = ""

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Couldn't start the microphone: \(error.localizedDescription)"
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        var latestTranscript = ""
        pendingTranscriptProvider = { latestTranscript }
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let result {
                latestTranscript = result.bestTranscription.formattedString
                Task { @MainActor in self?.partialTranscript = latestTranscript }
            }
            if error != nil {
                Task { @MainActor in self?.finishRecording(withText: latestTranscript) }
            }
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
        } catch {
            errorMessage = "Couldn't start the microphone: \(error.localizedDescription)"
            cleanUp()
            return
        }
    }

    /// Stops recording and delivers the transcript via the `onFinalText` callback passed to `start`.
    func stop() {
        guard isRecording else { return }
        let transcript = pendingTranscriptProvider?() ?? ""
        finishRecording(withText: transcript)
    }

    private func finishRecording(withText text: String) {
        guard isRecording else { return }
        isRecording = false
        cleanUp()
        partialTranscript = ""
        onFinalText?(text.trimmingCharacters(in: .whitespacesAndNewlines))
        onFinalText = nil
    }

    private func cleanUp() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
