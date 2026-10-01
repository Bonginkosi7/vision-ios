import SwiftUI

@main
struct VisionIOSApp: App {
    @AppStorage(AppSettings.themeKey) private var themeRaw: String = AppSettings.Theme.system.rawValue

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
