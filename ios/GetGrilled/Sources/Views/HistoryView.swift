import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.sessions.isEmpty && !viewModel.isLoading {
                    VStack(spacing: 8) {
                        Image(systemName: "clock").font(.largeTitle).foregroundStyle(.secondary)
                        Text("No sessions yet").foregroundStyle(.secondary)
                    }
                } else {
                    List(viewModel.sessions) { session in
                        row(for: session)
                    }
                    .refreshable { viewModel.load() }
                }
            }
            .navigationTitle("History")
            .onAppear { viewModel.load() }
            .overlay {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote).padding()
                }
            }
        }
    }

    private func row(for session: SessionSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.difficulty.displayName).font(.headline)
                Spacer()
                statusBadge(session.status)
            }
            if let date = session.startedAt {
                Text(date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let score = session.feedback {
                Text("Correctness \(score.correctnessScore) · Communication \(score.communicationScore) · Efficiency \(score.efficiencyScore)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func statusBadge(_ status: SessionStatus) -> some View {
        Text(status.rawValue.replacingOccurrences(of: "_", with: " "))
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(status == .completed ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
            .clipShape(Capsule())
    }
}

#Preview {
    HistoryView()
}
