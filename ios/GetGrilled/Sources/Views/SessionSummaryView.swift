import SwiftUI

struct SessionSummaryView: View {
    let roleTitle: String
    let seniority: Seniority
    let mode: SessionMode
    let rounds: [SessionRoundSummary]
    let overallSummary: String
    var onBackToDashboard: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Session complete").font(.onest(22, .bold)).foregroundStyle(DesignTokens.ink)
                    Text("\(roleTitle) · \(seniority.displayName) · \(mode.displayName) mode")
                        .font(.onest(13.5))
                        .foregroundStyle(DesignTokens.inkSoft)
                }

                ForEach(rounds) { round in
                    roundCard(round)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Overall").font(.onest(13, .bold)).foregroundStyle(DesignTokens.ink)
                    Text(overallSummary).font(.onest(12.5)).foregroundStyle(DesignTokens.ink).lineSpacing(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(DesignTokens.accentWash, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(DesignTokens.line, lineWidth: 1))

                Button {
                    onBackToDashboard()
                } label: {
                    Text("Back to dashboard")
                }
                .buttonStyle(.ggPrimary)
            }
            .padding(20)
        }
        .background(DesignTokens.bg.ignoresSafeArea())
    }

    private func roundCard(_ round: SessionRoundSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(round.type.displayName).font(.onest(13, .bold)).foregroundStyle(DesignTokens.ink)
                Spacer()
                statusPill(round)
            }
            if round.status == "skipped" {
                Text("Skipped").font(.onest(12.5)).foregroundStyle(DesignTokens.inkSoft)
            } else {
                if let selfEval = round.selfEval, let feedbackStatus = round.feedbackStatus {
                    HStack(spacing: 5) {
                        Text("You said").font(.onest(11)).foregroundStyle(DesignTokens.inkFaint)
                        vsPill(selfEval.displayName)
                        Text("· Interviewer said").font(.onest(11)).foregroundStyle(DesignTokens.inkFaint)
                        vsPill(feedbackStatus.displayName)
                    }
                }
                if let notes = round.feedbackNotes {
                    Text(notes).font(.onest(12.5)).foregroundStyle(DesignTokens.inkSoft).lineSpacing(2)
                }
            }
        }
        .cardStyle()
    }

    private func vsPill(_ text: String) -> some View {
        Text(text)
            .font(.onest(11, .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(DesignTokens.surface, in: Capsule())
            .overlay(Capsule().stroke(DesignTokens.line, lineWidth: 1))
            .foregroundStyle(DesignTokens.ink)
    }

    private func statusPill(_ round: SessionRoundSummary) -> some View {
        let label: String
        let tone: StatusPill.Tone
        switch round.feedbackStatus {
        case .strong, .good: label = round.feedbackStatus?.displayName ?? ""; tone = .success
        case .needsWork: label = "Needs work"; tone = .warn
        case nil: label = round.status == "skipped" ? "Skipped" : "—"; tone = .neutral
        }
        return StatusPill(text: label, tone: tone)
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
