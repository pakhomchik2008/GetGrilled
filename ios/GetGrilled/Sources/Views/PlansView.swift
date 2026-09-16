import SwiftUI

struct PlansView: View {
    @StateObject private var viewModel = PlansViewModel()
    @State private var showingCreate = false
    /// Set when the user taps "Continue plan" — RootView picks this up to launch a session.
    var onContinueStage: ((PrepPlanSummary, PlanStageRow) -> Void)?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.plans.isEmpty && !viewModel.isLoading {
                    VStack(spacing: 8) {
                        Image(systemName: "checklist").font(.largeTitle).foregroundStyle(.secondary)
                        Text("No prep plans yet").foregroundStyle(.secondary)
                    }
                } else {
                    List(viewModel.plans) { plan in
                        NavigationLink {
                            PlanDetailView(plan: plan, onContinueStage: onContinueStage)
                        } label: {
                            row(for: plan)
                        }
                    }
                    .refreshable { viewModel.load() }
                }
            }
            .navigationTitle("Prep plans")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingCreate = true } label: { Image(systemName: "plus") }
                }
            }
            .onAppear { viewModel.load() }
            .sheet(isPresented: $showingCreate) {
                CreatePlanView(viewModel: viewModel, isPresented: $showingCreate)
            }
            .overlay {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote).padding()
                }
            }
        }
    }

    private func row(for plan: PrepPlanSummary) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(Color(.systemGray5), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: CGFloat(plan.progressPercent) / 100)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(plan.progressPercent)%").font(.caption2.bold())
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(plan.role_title).font(.headline)
                Text("\(plan.seniority.displayName) · \(plan.completedCount) of \(plan.totalCount) stages")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PlansView()
}
