import Foundation

/// Pure matching logic, direct port of FocusDomainMatcher.kt (itself a
/// port of desktop's FocusMode.ts normalizedHostname/matchBlockedDomain).
/// Kept separate from the session/timer state (FocusManager, in App/) so
/// the actual matching rule is directly unit-testable without Xcode.
public enum FocusDomainMatcher {
    public static func host(of url: String) -> String? {
        guard let host = URLComponents(string: url)?.host else { return nil }
        let lowercased = host.lowercased()
        return lowercased.hasPrefix("www.") ? String(lowercased.dropFirst(4)) : lowercased
    }

    /// Returns the matched blocklist entry (e.g. "youtube.com" for
    /// "m.youtube.com"), or nil if nothing in `blockedDomains` matches `url`.
    public static func matchBlockedDomain(url: String, blockedDomains: [String]) -> String? {
        guard let host = host(of: url) else { return nil }
        return blockedDomains.first { host == $0 || host.hasSuffix(".\($0)") }
    }
}
