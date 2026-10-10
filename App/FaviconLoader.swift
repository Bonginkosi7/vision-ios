import SwiftUI
import WebKit

/// Favicons for the browsing screens (History, Bookmarks, Downloads, Offline
/// Library). Two properties matter here:
///
/// - **Cached on disk**, so icons still show with no connection.
/// - **No third-party lookup.** An icon is saved at the moment you visit a
///   page, from the icon that page itself declares (`<link rel="icon">`, or
///   the site's own `/favicon.ico`) — the same request any browser makes. No
///   service is told which sites you browse, and private tabs never write to
///   the cache. Pages visited before this existed simply show the monochrome
///   fallback until they're visited again.
enum FaviconCache {
    private static let memory = NSCache<NSString, UIImage>()
    private static let refreshInterval: TimeInterval = 30 * 24 * 60 * 60
    private static let maxIconBytes = 300_000

    private static let directory: URL = {
        var dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("favicons", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? dir.setResourceValues(values)
        return dir
    }()

    /// Lowercased host without a leading "www.", so one site maps to one icon.
    static func key(forHost host: String) -> String {
        var key = host.lowercased()
        if key.hasPrefix("www.") { key.removeFirst(4) }
        return key
    }

    static func host(from urlString: String) -> String? {
        URL(string: urlString)?.host.map(key(forHost:))
    }

    private static func fileURL(forKey key: String) -> URL {
        let safe = key.map { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" ? $0 : "_" }
        return directory.appendingPathComponent(String(safe) + ".png")
    }

    static func image(forHost host: String) -> UIImage? {
        let key = key(forHost: host)
        if let cached = memory.object(forKey: key as NSString) { return cached }
        guard let data = try? Data(contentsOf: fileURL(forKey: key)), let image = UIImage(data: data) else { return nil }
        memory.setObject(image, forKey: key as NSString)
        return image
    }

    static func rememberInMemory(_ image: UIImage, forHost host: String) {
        memory.setObject(image, forKey: key(forHost: host) as NSString)
    }

    private static func isFresh(key: String) -> Bool {
        let url = fileURL(forKey: key)
        guard let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate else { return false }
        return Date().timeIntervalSince(modified) < refreshInterval
    }

    /// Normalises to at most 64x64 px so the cache stays tiny.
    private static func store(_ image: UIImage, key: String) {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return }
        let scale = min(1, 64 / longest)
        let size = CGSize(width: max(1, image.size.width * scale), height: max(1, image.size.height * scale))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let png = resized.pngData() else { return }
        try? png.write(to: fileURL(forKey: key), options: .atomic)
        memory.setObject(resized, forKey: key as NSString)
    }

    /// Called when a normal (non-private) page finishes loading.
    @MainActor
    static func captureIcon(from webView: WKWebView) {
        guard let pageURL = webView.url, pageURL.scheme == "http" || pageURL.scheme == "https",
              let host = pageURL.host else { return }
        let key = key(forHost: host)
        guard !isFresh(key: key) else { return }

        let script = """
        (function () {
          var links = document.querySelectorAll('link[rel~="icon"], link[rel="shortcut icon"], link[rel="apple-touch-icon"], link[rel="apple-touch-icon-precomposed"]');
          var pick = null;
          for (var i = 0; i < links.length; i++) {
            if ((links[i].getAttribute('rel') || '').toLowerCase().indexOf('apple') < 0) { pick = links[i]; break; }
          }
          if (!pick && links.length) { pick = links[0]; }
          return pick ? pick.href : null;
        })();
        """
        webView.evaluateJavaScript(script) { result, _ in
            let declared = (result as? String).flatMap(URL.init(string:))
            let conventional = URL(string: "/favicon.ico", relativeTo: pageURL)?.absoluteURL
            let candidates = [declared, conventional].compactMap { $0 }
            Task.detached(priority: .utility) { await download(candidates: candidates, key: key) }
        }
    }

    private static func download(candidates: [URL], key: String) async {
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.timeoutIntervalForRequest = 8
        let session = URLSession(configuration: config)
        for url in candidates where url.scheme == "http" || url.scheme == "https" {
            guard let (data, response) = try? await session.data(from: url),
                  (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? false,
                  data.count <= maxIconBytes,
                  let image = UIImage(data: data), image.size.width >= 8
            else { continue }   // missing, too large, or not a decodable raster (e.g. SVG): try the next candidate
            store(image, key: key)
            return
        }
    }
}

enum FaviconLoader {
    /// The cached icon if there is one. `remoteLookup` is only for the New Tab
    /// shortcuts row, which has always used a public favicon service for
    /// user-chosen sites; the browsing screens never pass it.
    static func load(host: String, remoteLookup: Bool = false) async -> UIImage? {
        if let cached = FaviconCache.image(forHost: host) { return cached }
        guard remoteLookup,
              let url = URL(string: "https://www.google.com/s2/favicons?sz=64&domain=\(host)"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data)
        else { return nil }
        FaviconCache.rememberInMemory(image, forHost: host)
        return image
    }
}

/// A site's real favicon on a light tile (icons are drawn for light
/// backgrounds), or a quiet monochrome globe while it loads or when none was
/// ever captured — never a made-up brand icon.
struct FaviconView: View {
    let host: String
    var size: CGFloat = 28
    var remoteLookup = false
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(image == nil ? DesignSystem.bgRaised : Color(white: 0.96))
            if let image {
                Image(uiImage: image).resizable().interpolation(.medium).scaledToFit().padding(size * 0.17)
            } else {
                Image(systemName: "globe").font(.system(size: size * 0.5)).foregroundStyle(DesignSystem.textMuted2)
            }
        }
        .frame(width: size, height: size)
        .task(id: host) { image = await FaviconLoader.load(host: host, remoteLookup: remoteLookup) }
        .accessibilityHidden(true)
    }
}
