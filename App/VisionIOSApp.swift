import SwiftUI

@main
struct VisionIOSApp: App {
    var body: some Scene {
        WindowGroup {
            MainBrowserView()
                .preferredColorScheme(.dark)
        }
    }
}
