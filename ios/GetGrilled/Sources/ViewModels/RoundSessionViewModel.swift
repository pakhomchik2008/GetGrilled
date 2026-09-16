import Foundation

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
    @Published private(set) var overallSummary: String?
    @Published private(set) var roundSummaries: [SessionRoundSummary] = []
    @Published var errorMessage: String?

    private(set) var sessionId: String?
    private(set) var currentRound: RoundRef?
    private(set) var totalRounds: Int = 3
    /// Set after finishing a round, shown next to the AI's own verdict once it arrives.
    private var pendingSelfEvalForSummary: SelfEval?
    private var lastRoundResult: RoundFinishResult?

    private let api = RoundAPIClient()

    var isLastRound: Bool { (currentRound?.order ?? 0) >= totalRounds - 1 }

    func startSession() {
        guard !roleTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        errorMessage = nil
        Task {
            do {
                let response = try await api.createSession(
                    mode: mode,
                    roleTitle: roleTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                    seniority: seniority,
                    focusNotes: focusNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : focusNotes
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

    func send() {
        guard !isStreaming, let sessionId, let roundId = currentRound?.id else { return }
        let combined = combinedCandidateMessage()
        guard !combined.isEmpty else { return }
        messages.append(ChatMessage(role: .candidate, content: combined))
        codeText = language.starterCode
        explanationText = ""
        Task { await runStream { try await self.api.sendRoundMessage(sessionId: sessionId, roundId: roundId, content: combined) } }
    }

    func sendChip(_ action: ChipAction) {
        guard !isStreaming, let sessionId, let roundId = currentRound?.id else { return }
        Task { await runStream { try await self.api.sendRoundMessage(sessionId: sessionId, roundId: roundId, content: "", action: action) } }
    }

    /// "I'm done" — for Test mode, collects a self-rating first; Competition mode finishes immediately.
    func finishRoundTapped() {
        guard !isStreaming, let sessionId, let roundId = currentRound?.id else { return }
        let combined = combinedCandidateMessage()
        if !combined.isEmpty {
            messages.append(ChatMessage(role: .candidate, content: combined))
            codeText = language.starterCode
            explanationText = ""
        }
        let mode = self.mode
        Task {
            if !combined.isEmpty {
                await runStream { try await self.api.sendRoundMessage(sessionId: sessionId, roundId: roundId, content: combined) }
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
        } catch {
            errorMessage = "Connection issue: \(error.localizedDescription)"
        }
    }

    private func appendDelta(_ text: String, toMessageWithId id: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].content += text
    }
}
