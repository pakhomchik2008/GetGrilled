import Foundation

@MainActor
final class PlansViewModel: ObservableObject {
    @Published private(set) var plans: [PrepPlanSummary] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    // Create-plan form
    @Published var newRoleTitle: String = ""
    @Published var newSeniority: Seniority = .mid
    @Published var newCompanyContext: String = ""
    @Published var newFocusNotes: String = ""
    @Published private(set) var isCreating = false

    private let dataService = SupabaseDataService()
    private let api = RoundAPIClient()

    func load() {
        isLoading = true
        errorMessage = nil
        Task {
            defer { isLoading = false }
            do {
                plans = try await dataService.listPlans()
            } catch {
                errorMessage = "Couldn't load plans: \(error.localizedDescription)"
            }
        }
    }

    func createPlan(onDone: @escaping () -> Void) {
        let roleTitle = newRoleTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !roleTitle.isEmpty, !isCreating else { return }
        isCreating = true
        errorMessage = nil
        Task {
            defer { isCreating = false }
            do {
                _ = try await api.generatePlan(
                    roleTitle: roleTitle,
                    seniority: newSeniority,
                    companyContext: newCompanyContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : newCompanyContext,
                    focusNotes: newFocusNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : newFocusNotes
                )
                newRoleTitle = ""
                newCompanyContext = ""
                newFocusNotes = ""
                newSeniority = .mid
                load()
                onDone()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
