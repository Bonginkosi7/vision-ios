import SwiftUI

/// Real, persisted user settings — direct port of VisionSettings.kt,
/// scoped the same way Android's own Phase 1 comment describes: a handful
/// of scalar values, so UserDefaults (not GRDB) is the right data shape —
/// same reasoning as why Bookmarks/History/etc. use real SQLite instead.
/// Phase 3 ports exactly the two prefs this phase's own scope needs
/// (search engine, theme); Android's weather/profile/storage-limit/
/// background-refresh prefs land in later phases alongside the features
/// that actually use them.
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
}
