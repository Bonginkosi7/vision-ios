import Foundation

/// How long the splash screen has to stay up so it can actually be seen: [minimum] seconds counted from the
/// moment the app process started (not from when the first screen draws), never negative.
public enum SplashTiming {
    public static let minimumSeconds: TimeInterval = 3

    public static func remaining(processStart: Date, now: Date, minimum: TimeInterval = minimumSeconds) -> TimeInterval {
        max(0, minimum - now.timeIntervalSince(processStart))
    }
}
