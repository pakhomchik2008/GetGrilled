import Foundation

@MainActor
final class InterviewViewModel: ObservableObject {
    enum Phase: Equatable {
        case selectingDifficulty
        case interviewing
        case evaluating
        case showingFeedback
    }

    @Published private(set) var phase: Phase = .selectingDifficulty
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isStreaming = false
    @Published var codeText: String = ""
    @Published var explanationText: String = ""
    @Published var language: CodeLanguage = .python
    @Published private(set) var feedback: SessionFeedback?
    @Published var errorMessage: String?

    private var sessionId: String?
    private let api = InterviewAPIClient()

    func start(difficulty: Difficulty) {
        errorMessage = nil
        phase = .interviewing
        codeText = language.starterCode
        Task { await runStream { try await self.api.startInterview(difficulty: difficulty) } }
    }

    /// Swaps the editor to the new language's starter stub, unless the candidate already wrote something.
    func setLanguage(_ newLanguage: CodeLanguage) {
        if codeText.isEmpty || codeText == language.starterCode {
            codeText = newLanguage.starterCode
        }
        language = newLanguage
    }

    /// Restores an unfinished session (app relaunch mid-interview) from its saved transcript.
    func resume(from detail: SessionDetail) {
        errorMessage = nil
        sessionId = detail.id.uuidString
        messages = detail.transcript.map { ChatMessage(role: $0.role, content: $0.content) }
        codeText = language.starterCode
        phase = .interviewing
    }

    /// Sends the candidate's code + explanation as one chat turn.
    func send() {
        guard !isStreaming, let sessionId else { return }
        let combined = combinedCandidateMessage()
        guard !combined.isEmpty else { return }
        messages.append(ChatMessage(role: .candidate, content: combined))
        codeText = language.starterCode
        explanationText = ""
        Task { await runStream { try await self.api.sendMessage(sessionId: sessionId, content: combined) } }
    }

    func finish() {
        guard !isStreaming, let sessionId else { return }
        let combined = combinedCandidateMessage()
        if !combined.isEmpty {
            messages.append(ChatMessage(role: .candidate, content: combined))
            codeText = language.starterCode
            explanationText = ""
        }
        Task {
            // Flush the final explanation into the transcript before scoring, if there is one.
            if !combined.isEmpty {
                await runStream { try await self.api.sendMessage(sessionId: sessionId, content: combined) }
            }
            phase = .evaluating
            do {
                let result = try await api.finishInterview(sessionId: sessionId)
                feedback = result
                phase = .showingFeedback
            } catch {
                errorMessage = "Couldn't get feedback: \(error.localizedDescription)"
                phase = .interviewing
            }
        }
    }

    private func combinedCandidateMessage() -> String {
        var parts: [String] = []
        if !explanationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(explanationText)
        }
        let trimmedCode = codeText.trimmingCharacters(in: .whitespacesAndNewlines)
        let isUntouchedStub = trimmedCode.isEmpty || codeText == language.starterCode
        if !isUntouchedStub {
            parts.append("```\(language.rawValue)\n\(codeText)\n```")
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
                case .done(let sessionId):
                    self.sessionId = sessionId
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
