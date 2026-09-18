import Foundation

@MainActor
final class HistoryViewModel: ObservableObject {
    /// All past sessions for one role, most-recent group first — matches "a Bloomberg Software
    /// Engineer section with all its history in it" rather than one flat undifferentiated list.
    struct RoleGroup: Identifiable {
        let roleTitle: String
        let sessions: [V2SessionSummary]
        var id: String { roleTitle }
    }

    @Published private(set) var groups: [RoleGroup] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let service = SupabaseDataService()

    func load() {
        isLoading = true
        errorMessage = nil
        Task {
            defer { isLoading = false }
            do {
                let sessions = try await service.listV2Sessions()
                groups = Self.grouped(sessions)
            } catch {
                errorMessage = "Couldn't load history: \(error.localizedDescription)"
            }
        }
    }

    /// `sessions` arrives sorted most-recent-first from the query; grouping by first-seen role
    /// keeps that ordering, so the group with the most recent activity sorts first too.
    private static func grouped(_ sessions: [V2SessionSummary]) -> [RoleGroup] {
        var order: [String] = []
        var byRole: [String: [V2SessionSummary]] = [:]
        for session in sessions {
            if byRole[session.roleTitle] == nil {
                order.append(session.roleTitle)
            }
            byRole[session.roleTitle, default: []].append(session)
        }
        return order.map { RoleGroup(roleTitle: $0, sessions: byRole[$0] ?? []) }
    }
}
