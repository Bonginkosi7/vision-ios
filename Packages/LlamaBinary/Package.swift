// swift-tools-version:5.8
import PackageDescription

// llama.cpp's own official prebuilt xcframework (release b10549, MIT),
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
            url: "https://github.com/ggml-org/llama.cpp/releases/download/b10549/llama-b10549-xcframework.zip",
            checksum: "636709d4a7b49ac7f2ed6dc8a4de3f278c257cac7248fe40d6a513f671e4bff4"
        )
    ]
)
