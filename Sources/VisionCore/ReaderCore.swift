import Foundation

/// An article pulled out of a web page for Reader View. Port of desktop's readerCore.ts.
public struct ReaderArticle: Equatable, Identifiable {
    public let id: String
    public let sourceURL: String
    public let title: String
    public let byline: String
    public let siteName: String
    /// Article body as HTML. Untrusted: it is only ever shown with scripts switched off.
    public let content: String
    public let lang: String
    public let dir: String
    /// Rough reading time in whole minutes (at least 1).
    public let minutes: Int

    public init(id: String, sourceURL: String, title: String, byline: String, siteName: String, content: String, lang: String, dir: String, minutes: Int) {
        self.id = id
        self.sourceURL = sourceURL
        self.title = title
        self.byline = byline
        self.siteName = siteName
        self.content = content
        self.lang = lang
        self.dir = dir
        self.minutes = minutes
    }
}

public struct ReaderPrefs: Equatable {
    /// Percent of the base text size, 80–200.
    public var scalePercent: Int
    public var serif: Bool

    public init(scalePercent: Int = 100, serif: Bool = true) {
        self.scalePercent = ReaderCore.clampScale(scalePercent)
        self.serif = serif
    }
}

/// Mozilla's Readability.js (Apache-2.0) does the real article extraction; this wraps it so it can run inside a
/// page and hand back plain JSON, and builds the page the article is shown in.
public enum ReaderCore {
    /// The script to run in a page: defines Readability, parses a copy of the document, returns JSON text or null.
    public static func buildExtractionScript(readabilitySource: String) -> String {
        """
        (function () {
          try {
            \(readabilitySource)
            var article = new Readability(document.cloneNode(true)).parse();
            if (!article || !article.content) return null;
            return JSON.stringify({
              title: article.title || document.title || "",
              byline: article.byline || "",
              siteName: article.siteName || "",
              content: article.content,
              textLength: article.length || 0,
              lang: article.lang || document.documentElement.lang || "",
              dir: article.dir || document.documentElement.dir || ""
            });
          } catch (e) {
            return null;
          }
        })()
        """
    }

    /// Turns the script's JSON result into an article; nil when the page had no readable article.
    public static func parseExtraction(_ raw: Any?, id: String, sourceURL: String) -> ReaderArticle? {
        guard let text = raw as? String,
              let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = object["content"] as? String,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        let title = (object["title"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return ReaderArticle(
            id: id,
            sourceURL: sourceURL,
            title: title.isEmpty ? sourceURL : title,
            byline: (object["byline"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            siteName: (object["siteName"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            content: content,
            lang: object["lang"] as? String ?? "",
            dir: object["dir"] as? String ?? "",
            minutes: readingMinutes(textLength: (object["textLength"] as? NSNumber)?.intValue ?? 0)
        )
    }

    /// Whole minutes to read `textLength` characters of prose — never less than 1.
    public static func readingMinutes(textLength: Int) -> Int {
        guard textLength > 0 else { return 1 }
        return max(1, Int((Double(textLength) / 5.7 / 230).rounded()))
    }

    /// Reader View only makes sense for real web pages, not VISION's own pages, files or blank tabs.
    public static func canRead(url: String) -> Bool {
        guard let components = URLComponents(string: url), let scheme = components.scheme?.lowercased() else { return false }
        return (scheme == "http" || scheme == "https") && !(components.host ?? "").isEmpty
    }

    public static func clampScale(_ percent: Int) -> Int {
        min(200, max(80, Int((Double(percent) / 10).rounded()) * 10))
    }

    public static func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func host(of url: String) -> String {
        let host = URLComponents(string: url)?.host ?? ""
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// The full document shown in the reading view: dark, large, comfortable text. Its own policy allows images
    /// and inline styles and nothing else, and the web view that shows it has JavaScript turned off.
    public static func buildDocument(article: ReaderArticle, prefs: ReaderPrefs) -> String {
        let scale = clampScale(prefs.scalePercent)
        let family = prefs.serif
            ? "Georgia, 'Iowan Old Style', 'Times New Roman', serif"
            : "-apple-system, system-ui, sans-serif"
        let siteHost = host(of: article.sourceURL)
        let meta = [article.byline, siteHost.isEmpty ? article.siteName : siteHost, "\(article.minutes) min read"]
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map(escapeHTML)
            .joined(separator: " · ")
        let direction = article.dir == "rtl" ? "rtl" : "ltr"
        let fontSize = Double(19 * scale) / 100
        return """
        <!doctype html>
        <html lang="\(escapeHTML(article.lang.isEmpty ? "en" : article.lang))" dir="\(direction)">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src https: http: data:; style-src 'unsafe-inline'">
        <style>
          :root { color-scheme: dark; }
          html { background: #0a0a0a; -webkit-text-size-adjust: 100%; }
          body { margin: 0; padding: 24px 20px 96px; color: #e8e8e8; font-family: \(family); font-size: \(fontSize)px; line-height: 1.7; }
          main { max-width: 680px; margin: 0 auto; }
          h1.title { font-size: 1.6em; line-height: 1.25; margin: 0 0 8px; color: #fff; }
          .meta { color: #9a9a9a; font-size: 0.7em; margin-bottom: 28px; font-family: -apple-system, system-ui, sans-serif; }
          h1, h2, h3, h4 { color: #fff; line-height: 1.3; margin: 1.6em 0 0.5em; }
          p { margin: 0 0 1.1em; }
          a { color: #8ab4ff; }
          img, video, svg, figure { max-width: 100%; height: auto; }
          figure { margin: 1.4em 0; }
          figcaption { color: #9a9a9a; font-size: 0.75em; }
          blockquote { margin: 1.2em 0; padding: 0 0 0 1em; border-left: 3px solid #333; color: #cfcfcf; }
          pre, code { font-family: ui-monospace, Menlo, monospace; font-size: 0.85em; background: #151517; border-radius: 6px; }
          pre { padding: 14px; overflow-x: auto; }
          code { padding: 0.1em 0.3em; }
          table { border-collapse: collapse; max-width: 100%; display: block; overflow-x: auto; }
          td, th { border: 1px solid #26262a; padding: 6px 10px; }
        </style>
        </head>
        <body>
        <main>
        <h1 class="title">\(escapeHTML(article.title))</h1>
        <div class="meta">\(meta)</div>
        \(article.content)
        </main>
        </body>
        </html>
        """
    }
}
