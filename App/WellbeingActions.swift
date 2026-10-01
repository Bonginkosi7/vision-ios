import Foundation
import VisionCore

/// The real "take a break" side effect, shared between AdvisorView and
/// (in a later phase) the New Tab VISION Advisor widget so both trigger
/// the exact same behavior rather than two copies that could drift.
/// Direct port of WellbeingActions.kt, now including its real
/// reward-eligibility hook (Phase 7 closes the trim Phase 6 disclosed).
@MainActor
enum WellbeingActions {
    private static let minSessionForRewardMs: Double = 10 * 60 * 1000

    /// The break is always recorded for real, but only reward-eligible
    /// after 10+ real continuous minutes — read *before* recordBreak()
    /// resets the continuous-session clock, same ordering as
    /// WellbeingActions.kt, guarding against farming points by clicking
    /// repeatedly.
    static func takeBreak(wellbeingStore: WellbeingStore, rewardStore: RewardStore) {
        let earnedReward = WellbeingManager.shared.continuousSessionMs() >= minSessionForRewardMs
        try? wellbeingStore.recordBreak()
        WellbeingManager.shared.recordBreak()
        if earnedReward {
            let rewardEngine = RewardEngine(store: rewardStore)
            rewardEngine.awardIfEligible(type: .healthyBreak, note: "Took a healthy break")
            rewardEngine.awardIfEligible(type: .digitalBalance, note: "Kept a balanced browsing day")
        }
    }
}
