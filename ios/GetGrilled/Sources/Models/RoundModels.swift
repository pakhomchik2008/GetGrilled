import Foundation

enum Seniority: String, Codable, CaseIterable, Identifiable {
    case junior
    case mid
    case senior

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .junior: return "Junior"
        case .mid: return "Mid"
        case .senior: return "Senior"
        }
    }
}

enum SessionMode: String, Codable, CaseIterable, Identifiable {
    case test
    case competition

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .test: return "Test"
        case .competition: return "Competition"
        }
    }
}

enum RoundType: String, Codable, CaseIterable {
    case intro
    case technical
    case behavioral

    var displayName: String {
        switch self {
        case .intro: return "Intro"
        case .technical: return "Technical"
        case .behavioral: return "Behavioral"
        }
    }

    /// Only the Technical round shows a code editor.
    var usesCodeEditor: Bool { self == .technical }
}

enum SelfEval: String, Codable, CaseIterable, Identifiable {
    case rough
    case ok
    case strong

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rough: return "Rough"
        case .ok: return "OK"
        case .strong: return "Strong"
        }
    }
}

enum RoundFeedbackStatus: String, Codable {
    case strong
    case good
    case needsWork = "needs_work"

    var displayName: String {
        switch self {
        case .strong: return "Strong"
        case .good: return "Good"
        case .needsWork: return "Needs work"
        }
    }
}

enum ChipAction: String {
    case hint
    case repeatQuestion = "repeat"
}

// MARK: - API request/response payloads

struct RoundRef: Codable {
    let id: String
    let type: RoundType
    let order: Int
}

struct CreateSessionResponse: Codable {
    let sessionId: String
    let round: RoundRef
    let totalRounds: Int
}

struct RoundFeedback: Codable {
    let status: RoundFeedbackStatus
    let notes: String
}

struct RoundFinishResult: Codable {
    let id: String
    let status: String
    let feedback: RoundFeedback?
    let selfEval: SelfEval?

    enum CodingKeys: String, CodingKey {
        case id, status, feedback, selfEval
    }
}

struct RoundFinishResponse: Codable {
    let round: RoundFinishResult
    let nextRound: RoundRef?
}

struct SessionRoundSummary: Codable, Identifiable {
    let type: RoundType
    let status: String
    let selfEval: SelfEval?
    let feedbackStatus: RoundFeedbackStatus?
    let feedbackNotes: String?

    var id: String { type.rawValue }
}

struct SessionFinishResponse: Codable {
    let overallSummary: String
    let rounds: [SessionRoundSummary]
}
