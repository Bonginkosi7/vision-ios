import Foundation
import VisionCore

/// Real fetch for the New Tab "Top Stories — BBC News" section — direct
/// port of NewsLogic.kt's fetchTopHeadlines()/NewsService.ts's own
/// function. Same real feed, no API key, a plain URLSession GET (10s
/// timeout, matching Android/desktop's own REQUEST_TIMEOUT_MS). No
/// caching/persistence here either, matching both: every New Tab display
/// fetches fresh rather than reading a stale cache.
enum NewsClient {
    private static let feedURL = URL(string: "https://feeds.bbci.co.uk/news/world/rss.xml")!

    static func fetchTopHeadlines(limit: Int = 5) async -> [NewsHeadline] {
        var request = URLRequest(url: feedURL)
        request.timeoutInterval = 10
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let xml = String(data: data, encoding: .utf8) else { return [] }
            return NewsLogic.parseHeadlines(xml: xml, limit: limit)
        } catch {
            return []
        }
    }
}
