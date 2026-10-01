import SwiftUI

/// Real favicon fetch — the same public, keyless service Android's own
/// FaviconLoader.kt uses (google.com/s2/favicons), not a bundled/fabricated
/// icon set. In-memory cache only; a cold app start just re-fetches,
/// matching Android's own per-process cache.
enum FaviconLoader {
    private static var cache: [String: UIImage] = [:]

    static func load(host: String) async -> UIImage? {
        if let cached = cache[host] { return cached }
        guard let url = URL(string: "https://www.google.com/s2/favicons?sz=64&domain=\(host)") else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url), let image = UIImage(data: data) else { return nil }
        cache[host] = image
        return image
    }
}

/// A small, real favicon-backed image view — loads asynchronously and
/// falls back to a plain globe glyph while loading or on failure (never a
/// fabricated brand icon for a domain whose real favicon couldn't be
/// fetched).
struct FaviconView: View {
    let host: String
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable()
            } else {
                Image(systemName: "globe").resizable().padding(4).foregroundStyle(DesignSystem.textMuted2)
            }
        }
        .frame(width: 20, height: 20)
        .task { image = await FaviconLoader.load(host: host) }
    }
}
