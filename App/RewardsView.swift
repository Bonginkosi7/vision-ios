import SwiftUI
import VisionCore

/// Real per-category icons — cosmetic only, matching RewardsActivity.kt's
/// own CATEGORY_EMOJI map.
private let rewardCategoryEmoji: [RewardCategory: String] = [
    .health: "❤️", .learning: "🎓", .productivity: "📈", .consistency: "🛡️",
]

/// Real points/level/history screen — port of RewardsActivity.kt. Every
/// number here comes straight from RewardStore; nothing is seeded or
/// estimated. "How you earn points" only lists the real event types whose
/// trigger exists on iOS right now (see RewardRules.swift) — Android's
/// education-related rows aren't shown since there's no way to actually
/// earn them here yet, a disclosed trim rather than an inaccurate list.
struct RewardsView: View {
    @ObservedObject var rewardStore: RewardStore
    @Environment(\.dismiss) private var dismiss

    @State private var total = 0
    @State private var availableBalance = 0
    @State private var thisWeekByCategory: [RewardCategory: Int] = [:]
    @State private var recentEvents: [RewardEvent] = []

    private var level: Int { total / RewardRules.levelSize + 1 }
    private var pointsIntoLevel: Int { total % RewardRules.levelSize }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    levelCard
                    weekStatsRow
                    if let insight = weeklyInsight {
                        DesignSystem.tipCard(emoji: "💡", title: "This week's insight", subtitle: insight)
                            .accessibilityIdentifier("rewardsInsightCard")
                    }
                    qualifyingActionsSection
                    recentEventsSection
                }
                .padding(16)
            }
            .background(DesignSystem.bgCanvas.ignoresSafeArea())
            .navigationTitle("Rewards")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear(perform: refresh)
    }

    @ViewBuilder
    private var levelCard: some View {
        DesignSystem.card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Level \(level)")
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(DesignSystem.brandGradient))
                        .accessibilityIdentifier("rewardsLevelBadge")
                    Spacer()
                }
                Text(RewardRules.levelName(level))
                    .font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                    .accessibilityIdentifier("rewardsLevelName")
                Text("\(total) points")
                    .font(.system(size: 14)).foregroundStyle(DesignSystem.textMuted2)
                    .accessibilityIdentifier("rewardsTotalPoints")
                ProgressView(value: Double(pointsIntoLevel), total: Double(RewardRules.levelSize))
                    .tint(DesignSystem.visionPurple)
                Text("\(pointsIntoLevel) / \(RewardRules.levelSize) to next level")
                    .font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2)
                Text("\(availableBalance) available to redeem")
                    .font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2)
                    .accessibilityIdentifier("rewardsAvailableBalance")
            }
        }
    }

    @ViewBuilder
    private var weekStatsRow: some View {
        HStack(spacing: 12) {
            ForEach(RewardCategory.allCases, id: \.self) { category in
                DesignSystem.statMiniCard(
                    emoji: rewardCategoryEmoji[category] ?? "⭐",
                    value: "\(thisWeekByCategory[category] ?? 0)",
                    label: category.label
                )
            }
        }
        .accessibilityIdentifier("rewardsWeekStatsRow")
    }

    @ViewBuilder
    private var qualifyingActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DesignSystem.sectionLabel("How you earn points")
            ForEach(RewardEventType.allCases, id: \.self) { type in
                HStack(spacing: 12) {
                    DesignSystem.iconBadge(rewardCategoryEmoji[type.rule.category] ?? "⭐", size: 36, textSize: 16)
                    Text(type.rule.label).font(.system(size: 13)).foregroundStyle(.white)
                    Spacer()
                    Text("+\(type.rule.points)")
                        .font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(DesignSystem.visionPurple.opacity(0.3)))
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12).fill(DesignSystem.bgCard))
                .accessibilityIdentifier("rewardRuleRow_\(type.rawValue)")
            }
        }
    }

    @ViewBuilder
    private var recentEventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DesignSystem.sectionLabel("Recent activity")
            if recentEvents.isEmpty {
                Text("Nothing earned yet — go save a page offline, complete a task, or finish a focus session.")
                    .font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                    .accessibilityIdentifier("emptyRecentEventsText")
            } else {
                ForEach(recentEvents) { event in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.note).font(.system(size: 13)).foregroundStyle(.white)
                            Text(event.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 11)).foregroundStyle(DesignSystem.textMuted2)
                        }
                        Spacer()
                        Text("+\(event.points)").font(.system(size: 13, weight: .bold)).foregroundStyle(DesignSystem.statusSuccess)
                    }
                    .padding(.vertical, 6)
                    .accessibilityIdentifier("rewardEventRow_\(event.id)")
                }
            }
        }
    }

    /// Ported from RewardsActivity.kt's weeklyInsight() — the real
    /// top-earning category this week, or none if nothing's been earned.
    private var weeklyInsight: String? {
        guard let top = thisWeekByCategory.filter({ $0.value > 0 }).max(by: { $0.value < $1.value }) else { return nil }
        return RewardRules.categoryInsightTemplates[top.key]
    }

    private func refresh() {
        total = (try? rewardStore.total()) ?? 0
        availableBalance = (try? rewardStore.availableBalance()) ?? 0
        thisWeekByCategory = (try? rewardStore.pointsThisWeekByCategory()) ?? [:]
        recentEvents = (try? rewardStore.recent()) ?? []
    }
}
