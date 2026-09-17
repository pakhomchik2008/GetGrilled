import SwiftUI

struct PlansView: View {
    @StateObject private var viewModel = PlansViewModel()
    @State private var showingCreate = false
    /// Set when the user taps "Continue plan" — RootView picks this up to launch a session.
    var onContinueStage: ((PrepPlanSummary, PlanStageRow) -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if viewModel.plans.isEmpty && !viewModel.isLoading {
                        VStack(spacing: 8) {
                            Image(systemName: "checklist").font(.largeTitle).foregroundStyle(DesignTokens.inkFaint)
                            Text("No prep plans yet").font(.onest(13.5)).foregroundStyle(DesignTokens.inkSoft)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        ForEach(viewModel.plans) { plan in
                            NavigationLink {
                                PlanDetailView(plan: plan, onContinueStage: onContinueStage)
                            } label: {
                                row(for: plan)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button { showingCreate = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                            Text("New plan")
                        }
                        .font(.onest(13, .bold))
                        .foregroundStyle(DesignTokens.accentStrong)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(DesignTokens.line, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    )
                }
                .padding(20)
                .padding(.top, 12)
            }
            .background(DesignTokens.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { viewModel.load() }
            .onAppear { viewModel.load() }
            .sheet(isPresented: $showingCreate) {
                CreatePlanView(viewModel: viewModel, isPresented: $showingCreate)
            }
            .overlay {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage).font(.onest(12)).foregroundStyle(DesignTokens.danger).padding()
                }
            }
        }
    }

    private func row(for plan: PrepPlanSummary) -> some View {
        HStack(spacing: 12) {
            RingProgress(percent: plan.progressPercent)
            VStack(alignment: .leading, spacing: 3) {
                Text(plan.role_title).font(.onest(13.5, .bold)).foregroundStyle(DesignTokens.ink)
                Text("\(plan.seniority.displayName) · \(plan.completedCount) of \(plan.totalCount) stages")
                    .font(.onest(11.5))
                    .foregroundStyle(DesignTokens.inkFaint)
            }
            Spacer()
        }
        .cardStyle()
    }
}

#Preview {
    PlansView()
}
