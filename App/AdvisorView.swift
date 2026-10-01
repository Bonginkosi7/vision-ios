import SwiftUI
import VisionCore

/// Real wellbeing nudge screen — port of AdvisorActivity.kt. Quick stats
/// are real counts from WellbeingStore/WellbeingManager (never fabricated
/// "focus score" or similar this app has no honest basis to compute); the
/// suggestion banner is AdvisorLogic's pure rule-based threshold check,
/// explicitly not an AI feature despite Android's underlying interface
/// being named "AIAdvisorProvider" — the shipped implementation there is
/// fully local/rule-based too, so this isn't a disclosed trim, it's an
/// honest match.
struct AdvisorView: View {
    @ObservedObject var wellbeingStore: WellbeingStore
    @Environment(\.dismiss) private var dismiss

    @State private var breaksToday = 0
    @State private var distinctSitesToday = 0
    @State private var tabsOpenedToday = 0
    @State private var suggestion: AdvisorSuggestion?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    DesignSystem.sectionLabel("Today")
                    HStack(spacing: 12) {
                        DesignSystem.statMiniCard(emoji: "☕️", value: "\(breaksToday)", label: "Breaks")
                        DesignSystem.statMiniCard(emoji: "🌐", value: "\(distinctSitesToday)", label: "Sites visited")
                        DesignSystem.statMiniCard(emoji: "🗂️", value: "\(tabsOpenedToday)", label: "Tabs opened")
                    }
                    .accessibilityIdentifier("advisorQuickStatsRow")

                    if let suggestion {
                        DesignSystem.card {
                            VStack(alignment: .leading, spacing: 12) {
                                DesignSystem.sectionLabel("A nudge for you")
                                Text(suggestion.message)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white)
                                    .accessibilityIdentifier("advisorSuggestionMessage")
                                HStack(spacing: 8) {
                                    ForEach(suggestion.actions, id: \.label) { action in
                                        Button(action.label) { handle(action) }
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 14).padding(.vertical, 8)
                                            .background(Capsule().fill(DesignSystem.bgCanvas))
                                            .overlay(Capsule().stroke(DesignSystem.borderCard, lineWidth: 1))
                                            .accessibilityIdentifier("advisorAction_\(action.id)")
                                    }
                                }
                            }
                        }
                        .accessibilityIdentifier("advisorSuggestionCard")
                    } else {
                        DesignSystem.tipCard(
                            emoji: "🙂",
                            title: "Nothing to flag right now",
                            subtitle: "No nudges right now."
                        )
                        .accessibilityIdentifier("advisorNoSuggestion")
                    }
                }
                .padding(16)
            }
            .background(DesignSystem.bgCanvas.ignoresSafeArea())
            .navigationTitle("Advisor")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear(perform: refresh)
    }

    private func refresh() {
        breaksToday = (try? wellbeingStore.breaksToday()) ?? 0
        distinctSitesToday = (try? wellbeingStore.distinctSitesToday()) ?? 0
        tabsOpenedToday = WellbeingManager.shared.tabsOpenedToday()
        suggestion = AdvisorLogic.getSuggestion(continuousSessionMs: WellbeingManager.shared.continuousSessionMs())
    }

    /// Direct port of AdvisorActivity.kt's click handling: TAKE_BREAK and
    /// FIVE_MIN_RESET both just call takeBreak() and re-render — confirmed
    /// identical in the real source, not two features collapsed into one
    /// here. DISMISS clears the banner locally without recording anything.
    private func handle(_ action: AdvisorAction) {
        switch action.id {
        case .takeBreak, .fiveMinReset:
            WellbeingActions.takeBreak(wellbeingStore: wellbeingStore)
            refresh()
        case .dismiss:
            suggestion = nil
        }
    }
}
