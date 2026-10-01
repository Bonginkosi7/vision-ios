import Foundation

/// The one real gate every reward event passes through — direct port of
/// RewardEligibility.kt, pulled out so the dedupe/daily-limit rule is
/// directly unit-testable without a database, same reasoning as the real
/// Kotlin source.
public enum RewardEligibility {
    public enum DenialReason: Equatable {
        case dedupe
        case dailyLimit
    }

    public static func evaluate(
        rule: RewardRule,
        hasEventTypeToday: Bool,
        hasAwardForKey: Bool,
        countSinceStartOfToday: Int
    ) -> DenialReason? {
        if rule.dedupe == .oncePerDay && hasEventTypeToday { return .dedupe }
        if rule.dedupe == .onceEver && hasAwardForKey { return .dedupe }
        if let dailyLimit = rule.dailyLimit, countSinceStartOfToday >= dailyLimit { return .dailyLimit }
        return nil
    }
}
