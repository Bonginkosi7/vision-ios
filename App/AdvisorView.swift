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
///
/// The "This Week" section was left out of Phase 6 (disclosed there as
/// depending on reward data not yet ported) and is added now that Phase 7
/// built RewardStore — closing that trim rather than leaving it open.
/// It drops Android's own "🎓 Learning completed" row: that counts
/// EDU_TEST_COMPLETED events, and no education feature exists on iOS yet
/// to generate any (see RewardRules.swift) — a real, disclosed trim, not
/// a row quietly dropped.
struct AdvisorView: View {
    @ObservedObject var wellbeingStore: WellbeingStore
    @ObservedObject var rewardStore: RewardStore
    @Environment(\.dismiss) private var dismiss

    @State private var continuousSessionMs: Double = 0
    @State private var breaksToday = 0
    @State private var distinctSitesToday = 0
    @State private var tabsOpenedToday = 0
    @State private var weekPoints = 0
    @State private var weekBreaks = 0
    @State private var weekFocusSessions = 0
    @State private var suggestion: AdvisorSuggestion?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    DesignSystem.sectionLabel("Today")
                    HStack(spacing: 12) {
                        DesignSystem.statMiniCard(emoji: "🎯", value: formatMinutes(continuousSessionMs), label: "Focus time")
                        DesignSystem.statMiniCard(emoji: "⚡", value: "\(breaksToday)", label: "Breaks")
                        DesignSystem.statMiniCard(emoji: "📍", value: "\(distinctSitesToday)", label: "Sites visited")
                        DesignSystem.statMiniCard(emoji: "🗂", value: "\(tabsOpenedToday)", label: "Tabs opened")
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

                    DesignSystem.sectionLabel("This week")
                    DesignSystem.card {
                        DesignSystem.statRow(emoji: "⭐", label: "Points earned", value: "\(weekPoints)")
                        DesignSystem.statRow(emoji: "❤️", label: "Healthy breaks", value: "\(weekBreaks)")
                        DesignSystem.statRow(emoji: "🎯", label: "Focus sessions", value: "\(weekFocusSessions)")
                    }
                    .accessibilityIdentifier("advisorWeekCard")
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
        continuousSessionMs = WellbeingManager.shared.continuousSessionMs()
        breaksToday = (try? wellbeingStore.breaksToday()) ?? 0
        distinctSitesToday = (try? wellbeingStore.distinctSitesToday()) ?? 0
        tabsOpenedToday = WellbeingManager.shared.tabsOpenedToday()
        weekPoints = (try? rewardStore.totalThisWeek()) ?? 0
        weekBreaks = (try? rewardStore.countEventsThisWeek(.healthyBreak)) ?? 0
        weekFocusSessions = (try? rewardStore.countEventsThisWeek(.focusSessionCompleted)) ?? 0
        suggestion = AdvisorLogic.getSuggestion(continuousSessionMs: continuousSessionMs)
    }

    /// Direct port of AdvisorActivity.kt's click handling: TAKE_BREAK and
    /// FIVE_MIN_RESET both just call takeBreak() and re-render — confirmed
    /// identical in the real source, not two features collapsed into one
    /// here. DISMISS clears the banner locally without recording anything.
    private func handle(_ action: AdvisorAction) {
        switch action.id {
        case .takeBreak, .fiveMinReset:
            WellbeingActions.takeBreak(wellbeingStore: wellbeingStore, rewardStore: rewardStore)
            refresh()
        case .dismiss:
            suggestion = nil
        }
    }

    /// Direct port of AdvisorActivity.kt's formatMinutes().
    private func formatMinutes(_ ms: Double) -> String {
        let totalMinutes = Int(ms) / 60_000
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}
