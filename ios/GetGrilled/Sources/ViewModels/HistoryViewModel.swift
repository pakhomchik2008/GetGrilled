import Foundation

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published private(set) var sessions: [SessionSummary] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let service = SupabaseDataService()

    func load() {
        isLoading = true
        errorMessage = nil
        Task {
            defer { isLoading = false }
            do {
                sessions = try await service.listSessions()
            } catch {
                errorMessage = "Couldn't load history: \(error.localizedDescription)"
            }
        }
    }
}
