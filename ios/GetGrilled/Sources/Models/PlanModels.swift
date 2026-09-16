import Foundation

struct PlanStageRow: Codable, Identifiable {
    let id: String
    let stage_order: Int
    let title: String
    let focus_description: String
    let status: String
    let session_id: String?

    var isCompleted: Bool { status == "completed" }
}

struct PrepPlanSummary: Codable, Identifiable {
    let id: String
    let role_title: String
    let seniority: Seniority
    let company_context: String?
    let focus_notes: String?
    let created_at: String
    let plan_stages: [PlanStageRow]

    var completedCount: Int { plan_stages.filter(\.isCompleted).count }
    var totalCount: Int { plan_stages.count }
    var progressPercent: Int { totalCount == 0 ? 0 : Int(Double(completedCount) / Double(totalCount) * 100) }
    var sortedStages: [PlanStageRow] { plan_stages.sorted { $0.stage_order < $1.stage_order } }
    var nextPendingStage: PlanStageRow? { sortedStages.first { !$0.isCompleted } }
}
