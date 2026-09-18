import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("History")
                        .font(.onest(22, .bold))
                        .foregroundStyle(DesignTokens.ink)

                    if viewModel.groups.isEmpty && !viewModel.isLoading {
                        VStack(spacing: 8) {
                            Image(systemName: "clock").font(.largeTitle).foregroundStyle(DesignTokens.inkFaint)
                            Text("No sessions yet").font(.onest(13.5)).foregroundStyle(DesignTokens.inkSoft)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        ForEach(viewModel.groups) { group in
                            roleSection(group)
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

    private func roleSection(_ group: HistoryViewModel.RoleGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(group.roleTitle).font(.onest(15, .bold)).foregroundStyle(DesignTokens.ink)
                Spacer()
                Text(group.sessions.count == 1 ? "1 session" : "\(group.sessions.count) sessions")
                    .font(.onest(11.5))
                    .foregroundStyle(DesignTokens.inkFaint)
            }

            VStack(spacing: 0) {
                ForEach(Array(group.sessions.enumerated()), id: \.element.id) { index, session in
                    NavigationLink {
                        detail(for: session)
                    } label: {
                        row(for: session)
                    }
                    .buttonStyle(.plain)
                    if index != group.sessions.count - 1 {
                        Divider().overlay(DesignTokens.line)
                    }
                }
            }
            .cardStyle()
        }
    }

    private func row(for session: V2SessionSummary) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if let date = session.startedAt {
                        Text(date, style: .date).font(.onest(12.5, .semibold)).foregroundStyle(DesignTokens.ink)
                    }
                    Text("· \(session.seniority.displayName) · \(session.mode.displayName)")
                        .font(.onest(11.5))
                        .foregroundStyle(DesignTokens.inkFaint)
                }
                if let summary = session.overallSummary, !summary.isEmpty {
                    Text(summary).font(.onest(11)).foregroundStyle(DesignTokens.inkFaint).lineLimit(1)
                }
            }
            Spacer()
            statusPill(session.status)
            Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(DesignTokens.inkFaint)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func statusPill(_ status: SessionStatus) -> some View {
        StatusPill(
            text: status.rawValue.replacingOccurrences(of: "_", with: " "),
            tone: status == .completed ? .success : .warn
        )
    }

    private func detail(for session: V2SessionSummary) -> some View {
        SessionSummaryView(
            roleTitle: session.roleTitle,
            seniority: session.seniority,
            mode: session.mode,
            rounds: session.orderedRoundSummaries,
            overallSummary: session.overallSummary ?? "This session hasn't finished yet — no summary available.",
            showsFooterButton: false
        )
    }
}

#Preview {
    HistoryView()
}
