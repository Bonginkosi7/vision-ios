import Foundation

/// Thin wrapper over the real build-time Info.plist values — see
/// project.yml for where these actually come from (baked in at build time
/// via Xcode's `$(VAR)` build-setting substitution, the same real "injected
/// once per build, not read live from whoever launches the app" model
/// FirebaseConfig.kt uses on Android via Gradle's buildConfigField, now
/// that desktop's own equivalent config.ts does the same via esbuild's
/// `define`). Empty by default — every caller checks isConfigured() and
/// degrades honestly, same as Android/desktop.
enum FirebaseConfig {
    static var apiKey: String {
        Bundle.main.object(forInfoDictionaryKey: "VisionFirebaseAPIKey") as? String ?? ""
    }

    static var projectID: String {
        Bundle.main.object(forInfoDictionaryKey: "VisionFirebaseProjectID") as? String ?? ""
    }

    static func isConfigured() -> Bool {
        !apiKey.isEmpty && !projectID.isEmpty
    }
}
