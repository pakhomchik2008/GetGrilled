import AVFoundation

/// On-device text-to-speech for the interviewer's replies.
@MainActor
final class Narrator: NSObject, ObservableObject {
    @Published private(set) var isSpeaking = false
    @Published var isMuted = true {
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
        utterance.voice = Self.bestAvailableVoice()
        // Slightly under the system default rate/pitch reads as calmer and more natural —
        // full default rate is what makes on-device TTS sound flat and rushed ("AI-y").
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.93
        utterance.pitchMultiplier = 0.98
        synthesizer.speak(utterance)
    }

    /// Picks the most natural-sounding installed en-US voice: Enhanced/Premium quality voices
    /// (downloaded via Settings > Accessibility > Spoken Content > Voices) beat the default
    /// compact ones Apple ships on every device out of the box, which is what actually sounds
    /// robotic. Among equal quality, prefers Apple's more natural-sounding named voices.
    private static func bestAvailableVoice() -> AVSpeechSynthesisVoice? {
        let preferredNames = ["Ava", "Zoe", "Nathan", "Evan", "Samantha", "Allison", "Nicky", "Tom"]
        let candidates = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "en-US" }
        guard !candidates.isEmpty else { return AVSpeechSynthesisVoice(language: "en-US") }

        func qualityRank(_ voice: AVSpeechSynthesisVoice) -> Int {
            switch voice.quality {
            case .premium: return 2
            case .enhanced: return 1
            default: return 0
            }
        }
        return candidates.sorted { a, b in
            let qa = qualityRank(a), qb = qualityRank(b)
            if qa != qb { return qa > qb }
            let pa = preferredNames.firstIndex(where: a.name.contains) ?? Int.max
            let pb = preferredNames.firstIndex(where: b.name.contains) ?? Int.max
            return pa < pb
        }.first
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
