import Foundation

enum SessionStatus: String, Codable {
    case started
    case inProgress = "in_progress"
    case awaitingFeedback = "awaiting_feedback"
    case completed

    var isResumable: Bool {
        self != .completed
    }
}

struct SessionSummary: Codable, Identifiable {
    let id: UUID
    let difficulty: Difficulty
    let status: SessionStatus
    let startedAtRaw: String
    let completedAtRaw: String?
    let feedback: SessionFeedback?

    enum CodingKeys: String, CodingKey {
        case id, difficulty, status
        case startedAtRaw = "started_at"
        case completedAtRaw = "completed_at"
        case feedback = "session_feedback"
    }

    var startedAt: Date? { Self.parseDate(startedAtRaw) }
    var completedAt: Date? { completedAtRaw.flatMap(Self.parseDate) }

    private static func parseDate(_ string: String) -> Date? {
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
