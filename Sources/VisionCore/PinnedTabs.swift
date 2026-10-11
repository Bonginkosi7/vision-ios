import Foundation

/// Rules for pinned tabs: they sit first in the tab list and the set of pinned
/// addresses is remembered between launches. Mirrors desktop's src/shared/pinnedTabs.ts.
public enum PinnedTabs {
    /// Pinned tabs are meant to stay open; a handful is plenty.
    public static let maxCount = 12

    /// Pinned items first, each group keeping the order it already had.
    public static func pinnedFirst<T>(_ items: [T], isPinned: (T) -> Bool) -> [T] {
        items.filter(isPinned) + items.filter { !isPinned($0) }
    }

    /// Only real web pages are worth reopening at the next launch — never duplicates or non-web addresses.
    public static func sanitize(_ urls: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in urls {
            let url = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isPinnable(url), seen.insert(url).inserted else { continue }
            result.append(url)
            if result.count >= maxCount { break }
        }
        return result
    }

    public static func isPinnable(_ url: String) -> Bool {
        guard let comps = URLComponents(string: url), let scheme = comps.scheme?.lowercased(),
              scheme == "http" || scheme == "https", let host = comps.host, !host.isEmpty else { return false }
        return true
    }
}
