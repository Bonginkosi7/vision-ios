import SwiftUI

@main
struct VisionIOSApp: App {
    @AppStorage(AppSettings.themeKey) private var themeRaw: String = AppSettings.Theme.system.rawValue
    @State private var showSplash = VisionIOSApp.splashEnabled

    /// UI tests skip the splash (they would only be waiting on it).
    private static var splashEnabled: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-UITestSkipSplash") { return false }
        #endif
        return true
    }

    init() {
        // App.init() isn't guaranteed MainActor-isolated by the SwiftUI
        // protocol itself (only `body` is) — hopping via Task here is what
        // makes calling the MainActor-isolated AnalyticsClient safe from
        // either case, rather than assuming isolation that may not hold.
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-UITestRecordOneSync") { LicenceUsageStore.shared.recordSync() }
        #endif
        Task { @MainActor in
            AnalyticsClient.shared.start()
            LicenceManager.shared.startBackgroundWork()
            await PrivacyService.retryPendingServerDeletion()
        }
    }

    var body: some Scene {
        WindowGroup {
            // nil here is a real, deliberate value for .system — it tells
            // SwiftUI "no preference, inherit whatever the OS's own
            // appearance actually is" rather than a fallback standing in
            // for a missing choice.
            ZStack {
                MainBrowserView()
                if showSplash {
                    SplashOverlay()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .task {
                let remaining = SplashOverlay.remainingSeconds()
                if remaining > 0 { try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000)) }
                withAnimation(.easeOut(duration: 0.25)) { showSplash = false }
            }
                // Black and white: system controls (Done buttons, pickers,
                // toggles) take the primary text colour — white on the dark
                // screens, black on a light system screen — not iOS blue.
                .tint(Color.primary)
                .preferredColorScheme((AppSettings.Theme(rawValue: themeRaw) ?? .system).colorScheme)
        }
    }
}
