import Foundation

/// In-process wellbeing state — direct port of WellbeingManager.kt (itself
/// ported from desktop's WellbeingStore module-level variables). Deliberately
/// in-memory only, matching desktop's own documented tradeoff: tabs opened
/// today aren't persisted, so this under-counts "today" across a restart —
/// not worth more than a single overview number yet.
@MainActor
final class WellbeingManager {
    static let shared = WellbeingManager()

    private let appLaunchedAt = Date()
    private var lastBreakAt: Date?
    private var tabsOpenedThisSession = 0

    private init() {}

    /// Seconds of continuous activity since app launch or the last break,
    /// whichever is more recent.
    func continuousSessionMs() -> Double {
        Date().timeIntervalSince(lastBreakAt ?? appLaunchedAt) * 1000
    }

    func recordBreak() {
        lastBreakAt = Date()
    }

    func recordTabOpened() {
        tabsOpenedThisSession += 1
    }

    func tabsOpenedToday() -> Int {
        tabsOpenedThisSession
    }
}
