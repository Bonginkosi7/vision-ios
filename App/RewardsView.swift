import SwiftUI
import VisionCore

/// Real points/level/history screen — port of RewardsActivity.kt. Every number
/// here comes straight from RewardStore; nothing is seeded or estimated.
/// "How you earn points" only lists the real event types whose trigger exists
/// on iOS right now (see RewardRules.swift) — Android's education-related rows
/// aren't shown since there's no way to earn them here yet, a disclosed trim
/// rather than an inaccurate list.
///
/// Layout: one level card, a row of this week's four category totals, an
/// optional insight, then plain text lists. No icons or emoji — the numbers and
/// labels are the content.
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
                VStack(alignment: .leading, spacing: DesignSystem.Space.xl) {
                    levelCard
                    weekStatsRow
                    if let insight = weeklyInsight {
                        DesignSystem.tipCard(title: "This week's insight", subtitle: insight)
                            .accessibilityIdentifier("rewardsInsightCard")
                    }
                    qualifyingActionsSection
                    recentEventsSection
                }
                .padding(DesignSystem.Space.l)
            }
            .navigationTitle("Rewards")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .visionScreen()
        }
        .onAppear(perform: refresh)
    }

    private var levelCard: some View {
        DesignSystem.card {
            VStack(alignment: .leading, spacing: DesignSystem.Space.s) {
                Text("Level \(level)")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(DesignSystem.textMuted2)
                    .accessibilityIdentifier("rewardsLevelBadge")
                Text(RewardRules.levelName(level))
                    .font(.system(size: 24, weight: .semibold)).foregroundStyle(.white)
                    .accessibilityIdentifier("rewardsLevelName")
                Text("\(total) points total")
                    .font(.system(size: 14)).foregroundStyle(DesignSystem.textMuted2)
                    .accessibilityIdentifier("rewardsTotalPoints")

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(DesignSystem.bgRaised)
                        Capsule().fill(Color.white)
                            .frame(width: geometry.size.width * CGFloat(pointsIntoLevel) / CGFloat(max(RewardRules.levelSize, 1)))
                    }
                }
                .frame(height: 6)
                .padding(.top, DesignSystem.Space.xs)

                HStack {
                    Text("\(pointsIntoLevel) / \(RewardRules.levelSize) to next level")
                        .font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2)
                    Spacer()
                    Text("\(availableBalance) available to redeem")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                        .accessibilityIdentifier("rewardsAvailableBalance")
                }
            }
        }
    }

    private var weekStatsRow: some View {
        HStack(spacing: DesignSystem.Space.s) {
            ForEach(RewardCategory.allCases, id: \.self) { category in
                DesignSystem.statMiniCard(value: "\(thisWeekByCategory[category] ?? 0)", label: category.label)
            }
        }
        .accessibilityIdentifier("rewardsWeekStatsRow")
    }

    private var qualifyingActionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Space.m) {
            DesignSystem.sectionLabel("How you earn points")
            DesignSystem.card {
                let types = Array(RewardEventType.allCases)
                ForEach(Array(types.enumerated()), id: \.element) { index, type in
                    HStack(spacing: DesignSystem.Space.m) {
                        Text(type.rule.label).font(.system(size: 15)).foregroundStyle(.white)
                        Spacer()
                        Text("+\(type.rule.points)")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    }
                    .padding(.vertical, DesignSystem.Space.m)
                    .accessibilityIdentifier("rewardRuleRow_\(type.rawValue)")
                    if index < types.count - 1 { DesignSystem.divider() }
                }
            }
        }
    }

    private var recentEventsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Space.m) {
            DesignSystem.sectionLabel("Recent activity")
            if recentEvents.isEmpty {
                Text("Nothing earned yet — go save a page offline, complete a task, or finish a focus session.")
                    .font(.system(size: 14)).foregroundStyle(DesignSystem.textMuted2)
                    .accessibilityIdentifier("emptyRecentEventsText")
            } else {
                DesignSystem.card {
                    ForEach(Array(recentEvents.enumerated()), id: \.element.id) { index, event in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.note).font(.system(size: 15)).foregroundStyle(.white)
                                Text(event.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2)
                            }
                            Spacer()
                            Text("+\(event.points)").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                        }
                        .padding(.vertical, DesignSystem.Space.m)
                        .accessibilityIdentifier("rewardEventRow_\(event.id)")
                        if index < recentEvents.count - 1 { DesignSystem.divider() }
                    }
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
