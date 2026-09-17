import SwiftUI

struct PlanDetailView: View {
    let plan: PrepPlanSummary
    var onContinueStage: ((PrepPlanSummary, PlanStageRow) -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    RingProgress(percent: plan.progressPercent, size: 84, big: true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(plan.role_title).font(.onest(17, .bold)).foregroundStyle(DesignTokens.ink)
                        Text(plan.seniority.displayName).font(.onest(13)).foregroundStyle(DesignTokens.inkSoft)
                        if let companyContext = plan.company_context, !companyContext.isEmpty {
                            Text(companyContext).font(.onest(11.5)).foregroundStyle(DesignTokens.inkFaint)
                        }
                    }
                }

                VStack(spacing: 0) {
                    ForEach(plan.sortedStages) { stage in
                        stageRow(stage)
                        if stage.id != plan.sortedStages.last?.id {
                            Divider().overlay(DesignTokens.line)
                        }
                    }
                }

                if let next = plan.nextPendingStage {
                    Button {
                        onContinueStage?(plan, next)
                        dismiss()
                    } label: {
                        Text("Continue plan")
                    }
                    .buttonStyle(.ggPrimary)
                } else {
                    Text("All stages complete 🎉").font(.onest(13.5)).foregroundStyle(DesignTokens.inkSoft)
                }
            }
            .padding(20)
        }
        .background(DesignTokens.bg.ignoresSafeArea())
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stageRow(_ stage: PlanStageRow) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(stage.isCompleted ? DesignTokens.successWash : Color.clear)
                Circle()
                    .stroke(stage.isCompleted ? Color.clear : DesignTokens.line, lineWidth: 1.5)
                if stage.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(DesignTokens.success)
                }
            }
            .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(stage.title).font(.onest(13, .medium)).foregroundStyle(DesignTokens.ink)
                Text(stage.isCompleted ? "Completed" : stage.focus_description)
                    .font(.onest(11))
                    .foregroundStyle(DesignTokens.inkFaint)
            }
            Spacer()
        }
        .padding(.vertical, 9)
    }
}

#Preview {
    NavigationStack {
        PlanDetailView(plan: PrepPlanSummary(
            id: "1",
            role_title: "Backend Engineer",
            seniority: .senior,
            company_context: "Fintech",
            focus_notes: nil,
            created_at: "",
            plan_stages: [
                PlanStageRow(id: "a", stage_order: 0, title: "Recruiter-style intro", focus_description: "Background, motivation", status: "completed", session_id: nil),
                PlanStageRow(id: "b", stage_order: 1, title: "Coding — arrays & hashing", focus_description: "Two Sum, variants", status: "pending", session_id: nil)
            ]
        ))
    }
}
