import Foundation
import VisionCore

struct ActiveFocusSession {
    let id: String
    let startedAt: Date
    let endsAt: Date
    let plannedMinutes: Int
    var blockedAttempts: Int = 0
}

/// In-process session/timer state — direct port of FocusManager.kt (itself
/// the Android counterpart of desktop's FocusMode.ts). Deliberately
/// in-memory only, same as Android/desktop's own tradeoff: if the process
/// dies mid-session there's no timer left to fire, and
/// FocusStore.closeDanglingSessions() cleans up the dangling row at next
/// startup, rather than adding a background-task mechanism to make this
/// more durable than the feature it's porting.
@MainActor
final class FocusManager: ObservableObject {
    static let shared = FocusManager()

    @Published private(set) var activeSession: ActiveFocusSession?
    private var blockedDomains: [String] = []
    private var timer: Timer?

    var onSessionEnd: ((ActiveFocusSession, _ completedNaturally: Bool) -> Void)?

    private init() {}

    func setBlockedDomains(_ domains: [String]) {
        blockedDomains = domains
    }

    func startSession(id: String, startedAt: Date, plannedMinutes: Int) {
        endActiveSession(completedNaturally: false)
        let endsAt = startedAt.addingTimeInterval(TimeInterval(plannedMinutes * 60))
        activeSession = ActiveFocusSession(id: id, startedAt: startedAt, endsAt: endsAt, plannedMinutes: plannedMinutes)
        let interval = max(0, endsAt.timeIntervalSinceNow)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.endActiveSession(completedNaturally: true) }
        }
    }

    func stopSession() {
        endActiveSession(completedNaturally: false)
    }

    private func endActiveSession(completedNaturally: Bool) {
        timer?.invalidate()
        timer = nil
        guard let ended = activeSession else { return }
        activeSession = nil
        onSessionEnd?(ended, completedNaturally)
    }

    func matchBlockedDomain(url: String) -> String? {
        guard activeSession != nil else { return nil }
        return FocusDomainMatcher.matchBlockedDomain(url: url, blockedDomains: blockedDomains)
    }

    func recordBlockedAttempt() {
        guard activeSession != nil else { return }
        activeSession?.blockedAttempts += 1
    }
}
