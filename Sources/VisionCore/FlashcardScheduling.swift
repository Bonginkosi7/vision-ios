import Foundation

/// Same Leitner-style schedule as desktop's EduFlashcardStore.ts and
/// Android's FlashcardScheduling.kt (INTERVAL_TIERS_DAYS = [1, 3, 7, 14,
/// 30]) — advances one tier per confident review, resets to tier 0 on
/// "still learning". Pure logic, directly unit-testable without Xcode.
public enum FlashcardScheduling {
    public static let intervalTiersDays = [1, 3, 7, 14, 30]

    public static func nextTier(priorTier: Int, confident: Bool) -> Int {
        guard confident else { return 0 }
        return min(priorTier + 1, intervalTiersDays.count - 1)
    }

    public static func nextDueAt(now: Date, tier: Int) -> Date {
        now.addingTimeInterval(TimeInterval(intervalTiersDays[tier]) * 24 * 60 * 60)
    }

    /// -1 means never reviewed — distinct from a real tier-0 row, same
    /// reasoning as Flashcard.kt's own intervalDays getter.
    public static func intervalDays(forTier tier: Int) -> Int {
        tier < 0 ? 0 : intervalTiersDays[tier]
    }
}
