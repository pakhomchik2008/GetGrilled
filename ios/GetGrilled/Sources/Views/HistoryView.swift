import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("History")
                        .font(.onest(22, .bold))
                        .foregroundStyle(DesignTokens.ink)
                        .padding(.bottom, 14)

                    if viewModel.sessions.isEmpty && !viewModel.isLoading {
                        VStack(spacing: 8) {
                            Image(systemName: "clock").font(.largeTitle).foregroundStyle(DesignTokens.inkFaint)
                            Text("No sessions yet").font(.onest(13.5)).foregroundStyle(DesignTokens.inkSoft)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        ForEach(Array(viewModel.sessions.enumerated()), id: \.element.id) { index, session in
                            row(for: session)
                            if index != viewModel.sessions.count - 1 {
                                Divider().overlay(DesignTokens.line)
                            }
                        }
                    }
                }
                .padding(20)
                .padding(.top, 12)
            }
            .background(DesignTokens.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { viewModel.load() }
            .onAppear { viewModel.load() }
            .overlay {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage).font(.onest(12)).foregroundStyle(DesignTokens.danger).padding()
                }
            }
        }
    }

    private func row(for session: SessionSummary) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.difficulty.displayName).font(.onest(13.5, .semibold)).foregroundStyle(DesignTokens.ink)
                HStack(spacing: 6) {
                    if let date = session.startedAt {
                        Text(date, style: .date).font(.onest(11.5)).foregroundStyle(DesignTokens.inkFaint)
                    }
                    statusPill(session.status)
                }
                if let score = session.feedback {
                    Text("Correctness \(score.correctnessScore) · Communication \(score.communicationScore) · Efficiency \(score.efficiencyScore)")
                        .font(.onest(11))
                        .foregroundStyle(DesignTokens.inkFaint)
                }
            }
            Spacer()
            if let score = session.feedback {
                Text("\(score.correctnessScore)")
                    .font(.plexMono(12, .semibold))
                    .foregroundStyle(DesignTokens.inkSoft)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(DesignTokens.surface, in: Capsule())
                    .overlay(Capsule().stroke(DesignTokens.line, lineWidth: 1))
            }
        }
        .padding(.vertical, 12)
    }

    private func statusPill(_ status: SessionStatus) -> some View {
        StatusPill(
            text: status.rawValue.replacingOccurrences(of: "_", with: " "),
            tone: status == .completed ? .success : .warn
        )
    }
}

#Preview {
    HistoryView()
}
