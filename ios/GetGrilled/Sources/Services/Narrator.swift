import AVFoundation

/// On-device text-to-speech for the interviewer's replies.
@MainActor
final class Narrator: NSObject, ObservableObject {
    @Published private(set) var isSpeaking = false
    @Published var isMuted = false {
        didSet { if isMuted { stop() } }
    }

    private let synthesizer = AVSpeechSynthesizer()
    private var lastSpokenText: String?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        guard !isMuted, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        stop()
        lastSpokenText = text
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            return
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    /// Replays the last thing spoken, e.g. from a tap on the speaker icon.
    func replay() {
        guard let lastSpokenText else { return }
        speak(lastSpokenText)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}

extension Narrator: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = true }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
}
