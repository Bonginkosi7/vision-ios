// swift-tools-version:5.8
import PackageDescription

// VisionCore holds every platform-independent piece of logic this app
// needs — no SwiftUI/UIKit/WebKit/GRDB imports allowed in this target. That
// constraint is deliberate: it's what makes `swift test` runnable on this
// machine right now, with only Command Line Tools installed and no full
// Xcode/iOS SDK — the same real-verification discipline vision-android
// applies to its own pure-logic files (AddressResolverTest.kt,
// TabIndexingTest.kt run under plain JUnit, no emulator needed). Once the
// full iOS app target exists in Xcode, it depends on this package locally
// rather than duplicating these files — see App/README.md.
let package = Package(
    name: "VisionCore",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "VisionCore", targets: ["VisionCore"]),
    ],
    targets: [
        .target(name: "VisionCore"),
        .testTarget(name: "VisionCoreTests", dependencies: ["VisionCore"]),
    ]
)
