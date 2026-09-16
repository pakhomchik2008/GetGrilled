import SwiftUI

struct SessionSummaryView: View {
    let roleTitle: String
    let seniority: Seniority
    let mode: SessionMode
    let rounds: [SessionRoundSummary]
    let overallSummary: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Session complete").font(.largeTitle.bold())
                    Text("\(roleTitle) · \(seniority.displayName) · \(mode.displayName) mode")
                        .foregroundStyle(.secondary)
                }

                ForEach(rounds) { round in
                    roundCard(round)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Overall").font(.headline)
                    Text(overallSummary).foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
    }

    private func roundCard(_ round: SessionRoundSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(round.type.displayName).font(.headline)
                Spacer()
                statusPill(round)
            }
            if round.status == "skipped" {
                Text("Skipped").font(.subheadline).foregroundStyle(.secondary)
            } else {
                if let selfEval = round.selfEval, let feedbackStatus = round.feedbackStatus {
                    HStack(spacing: 6) {
                        Text("You said").font(.caption).foregroundStyle(.secondary)
                        Text(selfEval.displayName).font(.caption.bold())
                        Text("· Interviewer said").font(.caption).foregroundStyle(.secondary)
                        Text(feedbackStatus.displayName).font(.caption.bold())
                    }
                }
                if let notes = round.feedbackNotes {
                    Text(notes).font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func statusPill(_ round: SessionRoundSummary) -> some View {
        let label: String
        let color: Color
        switch round.feedbackStatus {
        case .strong, .good: label = round.feedbackStatus?.displayName ?? ""; color = .green
        case .needsWork: label = "Needs work"; color = .orange
        case nil: label = round.status == "skipped" ? "Skipped" : "—"; color = .gray
        }
        return Text(label)
            .font(.caption2.bold())
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.2), in: Capsule())
            .foregroundStyle(color)
    }
}

#Preview {
    SessionSummaryView(
        roleTitle: "Backend Engineer",
        seniority: .mid,
        mode: .test,
        rounds: [
            SessionRoundSummary(type: .intro, status: "completed", selfEval: .strong, feedbackStatus: .strong, feedbackNotes: "Clear, concise, good energy."),
            SessionRoundSummary(type: .technical, status: "completed", selfEval: .ok, feedbackStatus: .needsWork, feedbackNotes: "Correct solution, but went quiet while thinking."),
            SessionRoundSummary(type: .behavioral, status: "completed", selfEval: .ok, feedbackStatus: .good, feedbackNotes: "Specific example, clear outcome.")
        ],
        overallSummary: "You undersell your technical narration and your behavioral answers too — practice thinking out loud."
    )
}
