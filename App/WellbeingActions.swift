import Foundation

/// The real "take a break" side effect, shared between AdvisorView and
/// (in a later phase) the New Tab VISION Advisor widget so both trigger
/// the exact same behavior rather than two copies that could drift.
/// Direct port of WellbeingActions.kt, minus its reward-eligibility hook
/// (RewardEngine/RewardDbHelper don't exist on iOS yet — Phase 7 — so
/// this is a disclosed scope trim, not a silent omission: the break is
/// still always recorded for real, same as Android, just not yet
/// reward-eligible here).
@MainActor
enum WellbeingActions {
    static func takeBreak(wellbeingStore: WellbeingStore) {
        try? wellbeingStore.recordBreak()
        WellbeingManager.shared.recordBreak()
    }
}
