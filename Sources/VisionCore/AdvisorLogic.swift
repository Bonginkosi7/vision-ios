import Foundation

public enum AdvisorActionId {
    case takeBreak, fiveMinReset, dismiss
}

public struct AdvisorAction {
    public let id: AdvisorActionId
    public let label: String
}

public struct AdvisorSuggestion {
    public let message: String
    public let actions: [AdvisorAction]
}

/// Pure rule-based wellbeing nudge — direct port of AdvisorLogic.kt (itself
/// ported from desktop's LocalAdvisor, src/main/advisor/AdvisorProvider.ts).
/// Despite the interface name there ("AIAdvisorProvider"), the shipped
/// implementation is fully local and rule-based: no network call, no
/// model — just "have you been continuously active a while, maybe take a
/// break." That's exactly what's ported here, nothing more claimed.
public enum AdvisorLogic {
    private static let continuousSessionThresholdMs: Double = 45 * 60 * 1000

    public static func getSuggestion(continuousSessionMs: Double) -> AdvisorSuggestion? {
        guard continuousSessionMs >= continuousSessionThresholdMs else { return nil }
        let minutes = Int((continuousSessionMs / 60_000).rounded())
        return AdvisorSuggestion(
            message: "You've been active for \(minutes) minutes. A short break may help you reset your attention.",
            actions: [
                AdvisorAction(id: .takeBreak, label: "Take a break"),
                AdvisorAction(id: .fiveMinReset, label: "5-min reset"),
                AdvisorAction(id: .dismiss, label: "Dismiss"),
            ]
        )
    }
}
