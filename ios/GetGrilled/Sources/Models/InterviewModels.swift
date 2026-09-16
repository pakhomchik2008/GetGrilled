import Foundation

enum Difficulty: String, Codable, CaseIterable, Identifiable {
    case easy
    case medium
    case hard

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }
}

enum CodeLanguage: String, Codable, CaseIterable, Identifiable {
    case python
    case javascript

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .python: return "Python"
        case .javascript: return "JavaScript"
        }
    }

    /// Starting point for the editor so the candidate isn't staring at a blank box.
    var starterCode: String {
        switch self {
        case .python: return "def solve():\n    pass\n"
        case .javascript: return "function solve() {\n  \n}\n"
        }
    }
}

/// Transcript entry as stored by the backend.
struct TranscriptMessage: Codable, Equatable {
    enum Role: String, Codable {
        case interviewer
        case candidate
    }

    let role: Role
    let content: String
    let timestamp: String
}

/// UI-facing wrapper so SwiftUI lists have stable identity while streaming updates content in place.
struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    var role: TranscriptMessage.Role
    var content: String

    init(id: UUID = UUID(), role: TranscriptMessage.Role, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}

struct SessionFeedback: Codable, Equatable {
    let correctnessScore: Int
    let correctnessNotes: String
    let communicationScore: Int
    let communicationNotes: String
    let efficiencyScore: Int
    let efficiencyNotes: String
    let overallSummary: String

    enum CodingKeys: String, CodingKey {
        case correctnessScore = "correctness_score"
        case correctnessNotes = "correctness_notes"
        case communicationScore = "communication_score"
        case communicationNotes = "communication_notes"
        case efficiencyScore = "efficiency_score"
        case efficiencyNotes = "efficiency_notes"
        case overallSummary = "overall_summary"
    }
}
