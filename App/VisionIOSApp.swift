import SwiftUI

@main
struct VisionIOSApp: App {
    @AppStorage(AppSettings.themeKey) private var themeRaw: String = AppSettings.Theme.system.rawValue

    init() {
        // App.init() isn't guaranteed MainActor-isolated by the SwiftUI
        // protocol itself (only `body` is) — hopping via Task here is what
        // makes calling the MainActor-isolated AnalyticsClient safe from
        // either case, rather than assuming isolation that may not hold.
        Task { @MainActor in
            AnalyticsClient.shared.start()
        }
    }

    var body: some Scene {
        WindowGroup {
            // nil here is a real, deliberate value for .system — it tells
            // SwiftUI "no preference, inherit whatever the OS's own
            // appearance actually is" rather than a fallback standing in
            // for a missing choice.
            MainBrowserView()
                .preferredColorScheme((AppSettings.Theme(rawValue: themeRaw) ?? .system).colorScheme)
        }
    }
}
