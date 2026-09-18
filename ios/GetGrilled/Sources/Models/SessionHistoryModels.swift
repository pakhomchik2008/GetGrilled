import Foundation

func parseISODate(_ string: String) -> Date? {
    for formatOptions: ISO8601DateFormatter.Options in [
        [.withInternetDateTime, .withFractionalSeconds],
        [.withInternetDateTime]
    ] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = formatOptions
        if let date = formatter.date(from: string) {
            return date
        }
    }
    return nil
}

enum SessionStatus: String, Codable {
    case started
    case inProgress = "in_progress"
    case awaitingFeedback = "awaiting_feedback"
    case completed

    var isResumable: Bool {
        self != .completed
    }
}

struct SessionDetail: Codable {
    let id: UUID
    let difficulty: Difficulty
    let status: SessionStatus
    let transcript: [TranscriptMessage]

    enum CodingKeys: String, CodingKey {
        case id, difficulty, status, transcript
    }
}

// MARK: - v2 (round-based) history

/// One `session_rounds` row as read back from Supabase for History — same shape the live
/// round-session flow produces, just fetched instead of accumulated in memory.
struct V2RoundSummary: Codable {
    let type: RoundType
    let roundOrder: Int
    let status: String
    let selfEval: SelfEval?
    let feedbackStatus: RoundFeedbackStatus?
    let feedbackNotes: String?

    enum CodingKeys: String, CodingKey {
        case type = "round_type"
        case roundOrder = "round_order"
        case status
        case selfEval = "self_eval"
        case feedbackStatus = "feedback_status"
        case feedbackNotes = "feedback_notes"
    }
}

struct V2SessionSummary: Codable, Identifiable {
    let id: UUID
    let roleTitle: String
    let seniority: Seniority
    let mode: SessionMode
    let status: SessionStatus
    let startedAtRaw: String
    let completedAtRaw: String?
    let overallSummary: String?
    let rounds: [V2RoundSummary]

    enum CodingKeys: String, CodingKey {
        case id
        case roleTitle = "role_title"
        case seniority, mode, status
        case startedAtRaw = "started_at"
        case completedAtRaw = "completed_at"
        case overallSummary = "overall_summary"
        case rounds = "session_rounds"
    }

    var startedAt: Date? { parseISODate(startedAtRaw) }
    var completedAt: Date? { completedAtRaw.flatMap(parseISODate) }

    /// Sorted into round order and mapped to the same type `SessionSummaryView` already
    /// renders live, right after a session finishes — reused here for a past one.
    var orderedRoundSummaries: [SessionRoundSummary] {
        rounds
            .sorted { $0.roundOrder < $1.roundOrder }
            .map { SessionRoundSummary(type: $0.type, status: $0.status, selfEval: $0.selfEval, feedbackStatus: $0.feedbackStatus, feedbackNotes: $0.feedbackNotes) }
    }
}
