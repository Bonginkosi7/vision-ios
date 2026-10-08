import SwiftUI

/// Real, persisted user settings — direct port of VisionSettings.kt,
/// scoped the same way Android's own Phase 1 comment describes: a handful
/// of scalar values, so UserDefaults (not GRDB) is the right data shape —
/// same reasoning as why Bookmarks/History/etc. use real SQLite instead.
/// Phase 3 ports exactly the two prefs that phase's own scope needs
/// (search engine, theme); the real offline storage limit lands in the
/// VISION Ready phase alongside the screen that displays it. Android's
/// weather/profile/background-refresh prefs stay deferred — background
/// refresh has no real worker to flip on yet (see README's Smart Cache
/// scope trim, disclosed as far back as the Phase 2 migration comment).
enum AppSettings {
    enum SearchEngine: String, CaseIterable, Identifiable {
        case google, bing, duckduckgo

        var id: String { rawValue }

        var label: String {
            switch self {
            case .google: return "Google"
            case .bing: return "Bing"
            case .duckduckgo: return "DuckDuckGo"
            }
        }

        var queryUrl: String {
            switch self {
            case .google: return "https://www.google.com/search?q="
            case .bing: return "https://www.bing.com/search?q="
            case .duckduckgo: return "https://duckduckgo.com/?q="
            }
        }
    }

    enum Theme: String, CaseIterable, Identifiable {
        case system, light, dark

        var id: String { rawValue }

        var label: String {
            switch self {
            case .system: return "Follow system"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    // Not private: VisionIOSApp and SettingsView bind these same raw keys
    // directly via @AppStorage, the real SwiftUI mechanism for a value that
    // needs to reactively redraw the UI on change (plain UserDefaults
    // reads/writes here don't trigger a re-render by themselves) — sharing
    // the key name rather than hardcoding the string twice keeps both
    // routes to the same preference from drifting apart.
    static let searchEngineKey = "search_engine"
    static let themeKey = "theme"
    static let offlineStorageLimitMbKey = "offline_storage_limit_mb"
    static let analyticsEnabledKey = "analytics_enabled"
    static let diagnosticsEnabledKey = "diagnostics_enabled"
    private static let analyticsInstallationIDKey = "analytics_installation_id"

    /// Real options, direct port of VisionSettings.kt's own spinner list.
    static let offlineStorageLimitOptionsMb = [200, 500, 1000, 2000, 5000]

    static var searchEngine: SearchEngine {
        get {
            UserDefaults.standard.string(forKey: searchEngineKey).flatMap(SearchEngine.init(rawValue:)) ?? .google
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: searchEngineKey)
        }
    }

    static var theme: Theme {
        get {
            UserDefaults.standard.string(forKey: themeKey).flatMap(Theme.init(rawValue:)) ?? .system
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: themeKey)
        }
    }

    static var offlineStorageLimitMb: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: offlineStorageLimitMbKey)
            return offlineStorageLimitOptionsMb.contains(stored) ? stored : 500
        }
        set {
            UserDefaults.standard.set(newValue, forKey: offlineStorageLimitMbKey)
        }
    }

    /// Anonymous product-usage analytics (AnalyticsClient) — on by default,
    /// matching Android/desktop's own real default and their exact Settings
    /// disclosure copy. Never collects browsing history, page contents, or
    /// search queries; see AnalyticsEvent.swift for the full allowlist.
    /// `object(forKey:)` (not plain `bool(forKey:)`, which reads a missing
    /// key as `false`) is what makes "on by default" real for a fresh
    /// install rather than just for whichever launch first writes it.
    static var isAnalyticsEnabled: Bool {
        get {
            (UserDefaults.standard.object(forKey: analyticsEnabledKey) as? Bool) ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: analyticsEnabledKey)
        }
    }

    /// Anonymous crash/performance reporting (AnalyticsClient.reportCrash)
    /// — a separate toggle from the above, same as Android/desktop. On by
    /// default, matching their own real default.
    static var isDiagnosticsEnabled: Bool {
        get {
            (UserDefaults.standard.object(forKey: diagnosticsEnabledKey) as? Bool) ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: diagnosticsEnabledKey)
        }
    }

    /// A real, random per-install UUID (never a device identifier) —
    /// generated once on first real use and persisted, same real shape as
    /// Android/desktop's own analyticsInstallationId. Nil until
    /// AnalyticsClient.start() has run at least once.
    static var analyticsInstallationID: String? {
        get {
            UserDefaults.standard.string(forKey: analyticsInstallationIDKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: analyticsInstallationIDKey)
        }
    }
}
