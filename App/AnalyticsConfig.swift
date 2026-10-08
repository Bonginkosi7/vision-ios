import Foundation

/// Thin wrapper over the real build-time Info.plist values — same real
/// "injected once per build, not read live" model as FirebaseConfig.swift
/// (see its own doc comment), matching AnalyticsConfig.kt's own wrapper
/// over BuildConfig.ANALYTICS_BASE_URL/WRITE_KEY on Android. Empty by
/// default — no real vision-analytics-backend has been deployed yet (see
/// README), so isConfigured() reads false everywhere right now, same
/// honest unconfigured state Android/desktop are already in.
enum AnalyticsConfig {
    static var baseURL: String {
        Bundle.main.object(forInfoDictionaryKey: "VisionAnalyticsURL") as? String ?? ""
    }

    static var writeKey: String {
        Bundle.main.object(forInfoDictionaryKey: "VisionAnalyticsWriteKey") as? String ?? ""
    }

    /// WorkManager's own real minimum for periodic work on Android; iOS has
    /// no background-task scheduler wired up yet (see AnalyticsClient's own
    /// doc comment), so this instead paces a plain foreground `Timer` —
    /// still real periodic flushing, just only while the app is active.
    static let flushIntervalSeconds: TimeInterval = 15 * 60
    static let eventBatchSize = 200
    static let crashBatchSize = 20

    static func isConfigured() -> Bool {
        !baseURL.isEmpty && !writeKey.isEmpty
    }
}
