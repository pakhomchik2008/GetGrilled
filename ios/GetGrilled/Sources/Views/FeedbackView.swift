import SwiftUI

struct FeedbackView: View {
    let feedback: SessionFeedback

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Feedback")
                    .font(.largeTitle.bold())

                scoreSection(title: "Correctness", score: feedback.correctnessScore, notes: feedback.correctnessNotes)
                scoreSection(title: "Communication", score: feedback.communicationScore, notes: feedback.communicationNotes)
                scoreSection(title: "Efficiency", score: feedback.efficiencyScore, notes: feedback.efficiencyNotes)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Overall")
                        .font(.headline)
                    Text(feedback.overallSummary)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }

    private func scoreSection(title: String, score: Int, notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Text("\(score)/100").font(.headline.monospacedDigit())
            }
            Text(notes)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    FeedbackView(feedback: SessionFeedback(
        correctnessScore: 80,
        correctnessNotes: "Solution handles the general case correctly but misses the empty-input edge case.",
        communicationScore: 90,
        communicationNotes: "Clear explanation of the approach before coding.",
        efficiencyScore: 70,
        efficiencyNotes: "O(n^2) solution works but an O(n) hash-map approach was available.",
        overallSummary: "Solid attempt overall, work on edge cases and complexity analysis."
    ))
}
