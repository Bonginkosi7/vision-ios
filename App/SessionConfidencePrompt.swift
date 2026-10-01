import SwiftUI

/// Shared "wrap up this study-plan session" confidence self-report —
/// reused by both FlashcardsView and TakeExamView, direct port of the
/// identical `buildSessionConfidencePrompt()`/`renderSessionConfidencePrompt()`
/// Android duplicates verbatim between FlashcardsActivity.kt and
/// TakeExamActivity.kt. A quick honest self-report, not treated as
/// equivalent to actual test performance — matches desktop's own
/// maybeCompleteSession().
struct SessionConfidencePrompt: View {
    let completed: Bool
    let onRate: (Int) -> Void

    var body: some View {
        if completed {
            Text("Session complete — nice work.")
                .font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                .accessibilityIdentifier("studySessionComplete")
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("How confident do you feel about this topic?")
                    .font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                HStack(spacing: 4) {
                    confidenceButton(1, "😕 Not confident")
                    confidenceButton(2, "😐 Getting there")
                    confidenceButton(3, "🙂 Confident")
                    confidenceButton(4, "🔥 Very confident")
                }
            }
            .padding(.top, 12)
        }
    }

    @ViewBuilder
    private func confidenceButton(_ value: Int, _ label: String) -> some View {
        Button(label) { onRate(value) }
            .font(.system(size: 11, weight: .bold))
            .accessibilityIdentifier("studyConfidence_\(value)")
    }
}
