import Foundation

public struct NewsHeadline: Equatable, Identifiable {
    public var id: String { url }
    public let title: String
    public let url: String
    public let source: String
    public let publishedAt: String?
    public let thumbnailURL: String?

    public init(title: String, url: String, source: String, publishedAt: String?, thumbnailURL: String?) {
        self.title = title
        self.url = url
        self.source = source
        self.publishedAt = publishedAt
        self.thumbnailURL = thumbnailURL
    }
}

/// Pure RSS parsing for the real BBC World News feed
/// (https://feeds.bbci.co.uk/news/world/rss.xml, no API key) — direct port
/// of NewsLogic.kt (itself matching desktop's NewsService.ts): plain
/// regex/string extraction, not a full XML parser, the same deliberate
/// choice both of those made for a feed this simple and stable rather than
/// pulling in a new parsing dependency. Never fabricates a headline: an
/// item missing a title or link is skipped, and any parse failure yields
/// an empty array rather than invented content. `source` is hardcoded
/// "BBC News" (not parsed from the feed), matching both ports exactly.
public enum NewsLogic {
    public static func parseHeadlines(xml: String, limit: Int) -> [NewsHeadline] {
        var headlines: [NewsHeadline] = []
        for block in extractBlocks(xml, tag: "item") {
            guard let rawTitle = extractTag(block, tag: "title"), let rawLink = extractTag(block, tag: "link") else { continue }
            let title = decodeRSSText(rawTitle)
            let url = decodeRSSText(rawLink)
            guard !title.isEmpty, !url.isEmpty else { continue }
            let publishedAt = extractTag(block, tag: "pubDate").map(decodeRSSText)
            headlines.append(NewsHeadline(title: title, url: url, source: "BBC News", publishedAt: publishedAt, thumbnailURL: extractThumbnail(block)))
            if headlines.count >= limit { break }
        }
        return headlines
    }

    private static func extractBlocks(_ xml: String, tag: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: "<\(tag)>([\\s\\S]*?)</\(tag)>") else { return [] }
        let range = NSRange(xml.startIndex..., in: xml)
        return regex.matches(in: xml, range: range).compactMap { match in
            guard let r = Range(match.range(at: 1), in: xml) else { return nil }
            return String(xml[r])
        }
    }

    private static func extractTag(_ block: String, tag: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "<\(tag)>([\\s\\S]*?)</\(tag)>") else { return nil }
        let range = NSRange(block.startIndex..., in: block)
        guard let match = regex.firstMatch(in: block, range: range), let r = Range(match.range(at: 1), in: block) else { return nil }
        return String(block[r])
    }

    private static func extractThumbnail(_ block: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "<media:thumbnail[^>]*url=\"([^\"]+)\"") else { return nil }
        let range = NSRange(block.startIndex..., in: block)
        guard let match = regex.firstMatch(in: block, range: range), let r = Range(match.range(at: 1), in: block) else { return nil }
        return String(block[r])
    }

    /// Unwraps a CDATA section if present, then decodes the same six real
    /// HTML entities NewsLogic.kt/NewsService.ts decode — not a general
    /// HTML-entity decoder, same deliberately narrow bound.
    private static func decodeRSSText(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("<![CDATA[") && text.hasSuffix("]]>") {
            text = String(text.dropFirst(9).dropLast(3))
        }
        let entities: [(String, String)] = [("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'")]
        for (entity, replacement) in entities {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
