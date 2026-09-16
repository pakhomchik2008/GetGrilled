import SwiftUI

struct PlanDetailView: View {
    let plan: PrepPlanSummary
    var onContinueStage: ((PrepPlanSummary, PlanStageRow) -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle().stroke(Color(.systemGray5), lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: CGFloat(plan.progressPercent) / 100)
                            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(plan.progressPercent)%").font(.headline)
                    }
                    .frame(width: 84, height: 84)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(plan.role_title).font(.title3.bold())
                        Text(plan.seniority.displayName).foregroundStyle(.secondary)
                        if let companyContext = plan.company_context, !companyContext.isEmpty {
                            Text(companyContext).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                VStack(spacing: 0) {
                    ForEach(plan.sortedStages) { stage in
                        stageRow(stage)
                        if stage.id != plan.sortedStages.last?.id {
                            Divider()
                        }
                    }
                }

                if let next = plan.nextPendingStage {
                    Button {
                        onContinueStage?(plan, next)
                        dismiss()
                    } label: {
                        Text("Continue plan").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Text("All stages complete 🎉").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stageRow(_ stage: PlanStageRow) -> some View {
        HStack(spacing: 10) {
            Image(systemName: stage.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(stage.isCompleted ? Color.green : Color(.systemGray3))
            VStack(alignment: .leading, spacing: 1) {
                Text(stage.title).font(.subheadline.weight(.medium))
                Text(stage.isCompleted ? "Completed" : stage.focus_description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
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
