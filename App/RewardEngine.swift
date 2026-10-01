import Foundation
import VisionCore

/// The one real gate every reward event passes through — direct port of
/// RewardEngine.kt. A caller's job is only to decide whether a genuine
/// qualifying action happened (e.g. "did this Focus Session actually run
/// to completion"); this engine decides whether it's still eligible to
/// award points, using VisionCore's RewardEligibility rather than each
/// call site inventing its own guard. Cheap to construct fresh wherever
/// it's needed (it holds no state of its own beyond the store reference),
/// matching Android's own `RewardEngine(RewardDbHelper(context))` call
/// sites.
struct RewardEngine {
    private let store: RewardStore
    private let weeklyConsistencyMinDays = 4

    init(store: RewardStore) {
        self.store = store
    }

    @discardableResult
    func awardIfEligible(type: RewardEventType, note: String, dedupeKey: String? = nil) -> RewardEvent? {
        let rule = type.rule
        let hasEventTypeToday = rule.dedupe == .oncePerDay && ((try? store.hasEventTypeToday(type)) ?? false)
        let hasAwardForKey = rule.dedupe == .onceEver && ((try? store.hasAwardForKey(dedupeKey ?? note)) ?? false)
        let countToday = rule.dailyLimit != nil ? ((try? store.countEventsSince(type, since: store.startOfToday())) ?? 0) : 0

        let denial = RewardEligibility.evaluate(rule: rule, hasEventTypeToday: hasEventTypeToday, hasAwardForKey: hasAwardForKey, countSinceStartOfToday: countToday)
        guard denial == nil else { return nil }

        let event = try? store.award(type: type, note: note, dedupeKey: dedupeKey)
        if type != .weeklyConsistency {
            checkWeeklyConsistency()
        }
        return event
    }

    /// Real days-active tally, checked as a side effect of every other
    /// award rather than a separate timer — deduped once per real
    /// calendar week via a week-stamped key.
    private func checkWeeklyConsistency() {
        guard let activeDays = try? store.distinctActiveDaysThisWeek(), activeDays >= weeklyConsistencyMinDays else { return }
        let weekKey = "weekly_consistency:\(store.currentWeekLabel())"
        guard ((try? store.hasAwardForKey(weekKey)) ?? false) == false else { return }
        _ = try? store.award(type: .weeklyConsistency, note: "Stayed active on 4+ days this week", dedupeKey: weekKey)
    }
}
