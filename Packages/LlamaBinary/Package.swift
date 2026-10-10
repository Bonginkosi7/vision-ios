// swift-tools-version:5.8
import PackageDescription

// llama.cpp's own official prebuilt xcframework (release b9000, MIT),
// pinned by checksum. Used by the on-device Ask VISION model. Wrapping the
// release asset here (instead of depending on a third-party wrapper
// package) keeps the toolchain requirement at Swift 5.8 and the binary
// verifiably identical to llama.cpp's own release.
let package = Package(
    name: "LlamaBinary",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "llama", targets: ["llama"])
    ],
    targets: [
        .binaryTarget(
            name: "llama",
            url: "https://github.com/ggml-org/llama.cpp/releases/download/b9000/llama-b9000-xcframework.zip",
            checksum: "bb1e87e44543dd22dd9a9b344d529c3146e3f6a0364bef0570c407d5d69a3b0c"
        )
    ]
)
