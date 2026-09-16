import Foundation
import UIKit

@MainActor
final class RoundSessionViewModel: ObservableObject {
    enum Phase: Equatable {
        case setup
        case question
        case round
        case selfEval
        case evaluatingRound
        case summary
    }

    // Setup inputs
    @Published var mode: SessionMode = .test
    @Published var roleTitle: String = ""
    @Published var seniority: Seniority = .mid
    @Published var focusNotes: String = ""

    @Published private(set) var phase: Phase = .setup
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isStreaming = false
    @Published var codeText: String = ""
    @Published var explanationText: String = ""
    @Published var language: CodeLanguage = .python
    @Published var selfEvalChoice: SelfEval?
    /// A screenshot the candidate attached to explain their next message (e.g. a diagram).
    @Published var pendingImage: UIImage?
    @Published private(set) var overallSummary: String?
    @Published private(set) var roundSummaries: [SessionRoundSummary] = []
    @Published var errorMessage: String?
    /// Set when the backend rejects round/start with its weekly free-limit 403 — drives the
    /// paywall sheet instead of just showing errorMessage as inert text.
    @Published var limitReached = false

    private(set) var sessionId: String?
    private(set) var currentRound: RoundRef?
    private(set) var totalRounds: Int = 3
    private var planStageId: String?

    private let api = RoundAPIClient()
    let speechRecognizer = SpeechRecognizer()
    let narrator = Narrator()
    @Published var voiceInputErrorMessage: String?

    var isLastRound: Bool { (currentRound?.order ?? 0) >= totalRounds - 1 }

    /// Launches a session for a specific plan stage: always Test mode, personalization pulled
    /// from the plan, no Setup form shown.
    func startPlanStage(plan: PrepPlanSummary, stage: PlanStageRow) {
        mode = .test
        roleTitle = plan.role_title
        seniority = plan.seniority
        focusNotes = stage.focus_description
        planStageId = stage.id
        startSession()
    }

    /// Entry point for the manual Setup form — ensures we're not accidentally still tied to a
    /// previous plan stage.
    func startManualSession() {
        planStageId = nil
        startSession()
    }

    /// "Back to dashboard" from the summary screen. Role/seniority/focus notes are left as-is
    /// (convenient prefill for a next session) — everything session-specific is cleared.
    func resetToSetup() {
        narrator.stop()
        phase = .setup
        sessionId = nil
        currentRound = nil
        totalRounds = 3
        planStageId = nil
        messages = []
        codeText = language.starterCode
        explanationText = ""
        pendingImage = nil
        selfEvalChoice = nil
        overallSummary = nil
        roundSummaries = []
        errorMessage = nil
        limitReached = false
    }

    private func startSession() {
        guard !roleTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        errorMessage = nil
        Task {
            do {
                let response = try await api.createSession(
                    mode: mode,
                    roleTitle: roleTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                    seniority: seniority,
                    focusNotes: focusNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : focusNotes,
                    planStageId: planStageId
                )
                sessionId = response.sessionId
                currentRound = response.round
                totalRounds = response.totalRounds
                phase = .question
                codeText = language.starterCode
                await beginCurrentRound()
            } catch {
                errorMessage = "Couldn't start the interview: \(error.localizedDescription)"
            }
        }
    }

    /// "I'm ready to answer" — moves from the full-screen question reveal into the working round screen.
    func proceedToRound() {
        phase = .round
    }

    /// Swaps the editor to the new language's starter stub, unless the candidate already wrote something.
    func setLanguage(_ newLanguage: CodeLanguage) {
        if codeText.isEmpty || codeText == language.starterCode {
            codeText = newLanguage.starterCode
        }
        language = newLanguage
    }

    /// Push-to-talk: call on press-down. Transcribed text lands in `explanationText` on `stopVoiceInput`.
    func startVoiceInput() {
        guard !isStreaming else { return }
        Task {
            let status = await speechRecognizer.requestAuthorization()
            guard status == .authorized else {
                voiceInputErrorMessage = "Voice input needs microphone and speech recognition access — you can still type your answer."
                return
            }
            voiceInputErrorMessage = nil
            speechRecognizer.start { [weak self] transcript in
                guard let self, !transcript.isEmpty else { return }
                if self.explanationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.explanationText = transcript
                } else {
                    self.explanationText += " " + transcript
                }
            }
        }
    }

    /// Call on press-release.
    func stopVoiceInput() {
        speechRecognizer.stop()
    }

    func send() {
        guard !isStreaming, let sessionId, let roundId = currentRound?.id else { return }
        let combined = combinedCandidateMessage()
        let image = encodedPendingImage()
        guard !combined.isEmpty || image != nil else { return }
        messages.append(ChatMessage(role: .candidate, content: combined.isEmpty ? "📎 Screenshot" : combined))
        codeText = language.starterCode
        explanationText = ""
        pendingImage = nil
        Task {
            await runStream {
                try await self.api.sendRoundMessage(sessionId: sessionId, roundId: roundId, content: combined, imageBase64: image?.base64, imageMediaType: image?.mediaType)
            }
        }
    }

    func attachImage(_ image: UIImage) {
        pendingImage = image
    }

    func removePendingImage() {
        pendingImage = nil
    }

    /// Downscales to keep the upload small and re-encodes as JPEG — a full-res screenshot can
    /// be several MB, more than the interviewer needs to read a diagram or pasted code.
    private func encodedPendingImage() -> (base64: String, mediaType: String)? {
        guard let pendingImage else { return nil }
        let maxDimension: CGFloat = 1280
        let scale = min(1, maxDimension / max(pendingImage.size.width, pendingImage.size.height))
        let targetSize = CGSize(width: pendingImage.size.width * scale, height: pendingImage.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in pendingImage.draw(in: CGRect(origin: .zero, size: targetSize)) }
        guard let data = resized.jpegData(compressionQuality: 0.6) else { return nil }
        return (data.base64EncodedString(), "image/jpeg")
    }

    func sendChip(_ action: ChipAction) {
        guard !isStreaming, let sessionId, let roundId = currentRound?.id else { return }
        Task { await runStream { try await self.api.sendRoundMessage(sessionId: sessionId, roundId: roundId, content: "", action: action) } }
    }

    /// "I'm done" — for Test mode, collects a self-rating first; Competition mode finishes immediately.
    func finishRoundTapped() {
        guard !isStreaming, let sessionId, let roundId = currentRound?.id else { return }
        let combined = combinedCandidateMessage()
        let image = encodedPendingImage()
        if !combined.isEmpty || image != nil {
            messages.append(ChatMessage(role: .candidate, content: combined.isEmpty ? "📎 Screenshot" : combined))
            codeText = language.starterCode
            explanationText = ""
            pendingImage = nil
        }
        let mode = self.mode
        Task {
            if !combined.isEmpty || image != nil {
                await runStream {
                    try await self.api.sendRoundMessage(sessionId: sessionId, roundId: roundId, content: combined, imageBase64: image?.base64, imageMediaType: image?.mediaType)
                }
            }
            if mode == .test {
                self.phase = .selfEval
            } else {
                await self.finishRound(selfEval: nil)
            }
        }
    }

    func confirmSelfEval() {
        guard let selfEvalChoice else { return }
        Task { await finishRound(selfEval: selfEvalChoice) }
    }

    func skipRound() {
        guard !isStreaming, sessionId != nil, currentRound != nil else { return }
        Task { await finishRound(selfEval: selfEvalChoice, skip: true) }
    }

    private func finishRound(selfEval: SelfEval?, skip: Bool = false) async {
        guard let sessionId, let round = currentRound else { return }
        phase = .evaluatingRound
        do {
            let result = try await api.finishRound(sessionId: sessionId, roundId: round.id, selfEval: selfEval, skip: skip)
            selfEvalChoice = nil
            if let next = result.nextRound {
                currentRound = next
                messages = []
                codeText = language.starterCode
                explanationText = ""
                phase = .question
                await beginCurrentRound()
            } else {
                await finishSession()
            }
        } catch {
            errorMessage = "Couldn't finish this round: \(error.localizedDescription)"
            phase = .round
        }
    }

    private func finishSession() async {
        guard let sessionId else { return }
        do {
            let result = try await api.finishSession(sessionId: sessionId)
            overallSummary = result.overallSummary
            roundSummaries = result.rounds
            phase = .summary
        } catch {
            errorMessage = "Couldn't wrap up the session: \(error.localizedDescription)"
            phase = .round
        }
    }

    private func beginCurrentRound() async {
        guard let sessionId, let round = currentRound else { return }
        await runStream { try await self.api.startRound(sessionId: sessionId, roundId: round.id) }
    }

    private func combinedCandidateMessage() -> String {
        var parts: [String] = []
        if !explanationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(explanationText)
        }
        if currentRound?.type.usesCodeEditor == true {
            let trimmedCode = codeText.trimmingCharacters(in: .whitespacesAndNewlines)
            let isUntouchedStub = trimmedCode.isEmpty || codeText == language.starterCode
            if !isUntouchedStub {
                parts.append("```\(language.rawValue)\n\(codeText)\n```")
            }
        }
        return parts.joined(separator: "\n\n")
    }

    private func runStream(_ makeStream: () async throws -> AsyncThrowingStream<ChatStreamEvent, Error>) async {
        isStreaming = true
        defer { isStreaming = false }
        do {
            let stream = try await makeStream()
            let placeholderId = UUID()
            messages.append(ChatMessage(id: placeholderId, role: .interviewer, content: ""))
            for try await event in stream {
                switch event {
                case .delta(let text):
                    appendDelta(text, toMessageWithId: placeholderId)
                case .done:
                    break
                }
            }
            if let final = messages.first(where: { $0.id == placeholderId }) {
                narrator.speak(final.content)
            }
        } catch {
            if case APIError.server(403, _) = error {
                limitReached = true
            } else {
                errorMessage = "Connection issue: \(error.localizedDescription)"
            }
        }
    }

    private func appendDelta(_ text: String, toMessageWithId id: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].content += text
    }
}
