import Foundation

public struct ImportedBookmark: Equatable {
    public let url: String
    public let title: String
    /// The folder it was in ("" for the top level). VISION's iPhone bookmarks are a flat list, so this is only informational.
    public let folder: String

    public init(url: String, title: String, folder: String) {
        self.url = url
        self.title = title
        self.folder = folder
    }
}

public struct BookmarkImportSummary: Equatable {
    public let added: Int
    /// Already saved in VISION (same address).
    public let alreadyHad: Int
    /// Not an http(s) address (javascript:, place:, file: …) or a repeat inside the file.
    public let ignored: Int

    public init(added: Int, alreadyHad: Int, ignored: Int) {
        self.added = added
        self.alreadyHad = alreadyHad
        self.ignored = ignored
    }
}

/// Bookmark import from the standard "bookmarks.html" file every browser can export (Chrome, Edge, Firefox,
/// Safari, Brave…) — the Netscape bookmark format. Port of desktop's importBookmarks.ts.
public enum BookmarkImport {
    private static let rootFolderNames: Set<String> = [
        "bookmarks bar", "bookmarks menu", "bookmarks toolbar", "favorites", "favorites bar", "favourites",
        "other bookmarks", "other favorites", "mobile bookmarks", "bookmarks",
    ]

    private static let namedEntities: [String: String] = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " "]

    // swiftlint:disable:next force_try
    private static let tokenRegex = try! NSRegularExpression(
        pattern: "<DL\\b[^>]*>|</DL\\s*>|<H3\\b[^>]*>([\\s\\S]*?)</H3\\s*>|<A\\b([^>]*)>([\\s\\S]*?)</A\\s*>",
        options: [.caseInsensitive]
    )
    // swiftlint:disable:next force_try
    private static let hrefRegex = try! NSRegularExpression(pattern: "\\bHREF\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)')", options: [.caseInsensitive])
    // swiftlint:disable:next force_try
    private static let entityRegex = try! NSRegularExpression(pattern: "&(#x[0-9a-f]+|#\\d+|[a-z]+);", options: [.caseInsensitive])
    // swiftlint:disable:next force_try
    private static let tagRegex = try! NSRegularExpression(pattern: "<[^>]*>")

    public static func decodeEntities(_ text: String) -> String {
        let ns = text as NSString
        var result = ""
        var last = 0
        for match in entityRegex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            result += ns.substring(with: NSRange(location: last, length: match.range.location - last))
            let whole = ns.substring(with: match.range)
            let body = ns.substring(with: match.range(at: 1))
            var replacement = whole
            if body.hasPrefix("#") {
                let isHex = body.dropFirst().lowercased().hasPrefix("x")
                let digits = isHex ? String(body.dropFirst(2)) : String(body.dropFirst())
                if let code = UInt32(digits, radix: isHex ? 16 : 10), code > 0, let scalar = Unicode.Scalar(code) {
                    replacement = String(Character(scalar))
                }
            } else if let named = namedEntities[body.lowercased()] {
                replacement = named
            }
            result += replacement
            last = match.range.location + match.range.length
        }
        result += ns.substring(from: last)
        return result
    }

    private static func stripTags(_ text: String) -> String {
        let range = NSRange(location: 0, length: (text as NSString).length)
        let plain = tagRegex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
        let collapsed = decodeEntities(plain).split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return collapsed
    }

    public static func isWebURL(_ value: String) -> Bool {
        guard let components = URLComponents(string: value), let scheme = components.scheme?.lowercased() else { return false }
        return (scheme == "http" || scheme == "https") && !(components.host ?? "").isEmpty
    }

    /// Reads every link out of a Netscape-format bookmarks file, remembering which folder it was in.
    public static func parse(html: String) -> [ImportedBookmark] {
        let ns = html as NSString
        var folders: [String] = []
        var pending: String?
        var found: [ImportedBookmark] = []

        for match in tokenRegex.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            let text = ns.substring(with: match.range)
            let upper = text.uppercased()
            if upper.hasPrefix("<DL") {
                folders.append(pending ?? "")
                pending = nil
            } else if upper.hasPrefix("</DL") {
                _ = folders.popLast()
            } else if upper.hasPrefix("<H3") {
                pending = stripTags(group(match, 1, in: ns))
            } else {
                let attributes = group(match, 2, in: ns)
                var url = ""
                if let href = hrefRegex.firstMatch(in: attributes, range: NSRange(location: 0, length: (attributes as NSString).length)) {
                    let attrs = attributes as NSString
                    let doubleQuoted = href.range(at: 1).location != NSNotFound ? attrs.substring(with: href.range(at: 1)) : nil
                    let singleQuoted = href.range(at: 2).location != NSNotFound ? attrs.substring(with: href.range(at: 2)) : nil
                    url = decodeEntities((doubleQuoted ?? singleQuoted ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
                }
                let title = stripTags(group(match, 3, in: ns))
                var folder = folders.last(where: { !$0.isEmpty }) ?? ""
                if rootFolderNames.contains(folder.lowercased()) { folder = "" }
                found.append(ImportedBookmark(url: url, title: title.isEmpty ? url : title, folder: folder))
            }
        }
        return found
    }

    private static func group(_ match: NSTextCheckingResult, _ index: Int, in ns: NSString) -> String {
        let range = match.range(at: index)
        return range.location == NSNotFound ? "" : ns.substring(with: range)
    }

    /// Splits parsed bookmarks into the ones to add and a summary.
    public static func plan(_ parsed: [ImportedBookmark], isAlreadySaved: (String) -> Bool) -> (toAdd: [ImportedBookmark], summary: BookmarkImportSummary) {
        var seen = Set<String>()
        var toAdd: [ImportedBookmark] = []
        var alreadyHad = 0
        var ignored = 0
        for item in parsed {
            if !isWebURL(item.url) || seen.contains(item.url) {
                ignored += 1
                continue
            }
            seen.insert(item.url)
            if isAlreadySaved(item.url) {
                alreadyHad += 1
                continue
            }
            toAdd.append(item)
        }
        return (toAdd, BookmarkImportSummary(added: toAdd.count, alreadyHad: alreadyHad, ignored: ignored))
    }

    /// The sentence shown after an import.
    public static func describe(_ summary: BookmarkImportSummary) -> String {
        if summary.added == 0 && summary.alreadyHad == 0 { return "No bookmarks were found in that file." }
        var parts = ["Imported \(summary.added) bookmark\(summary.added == 1 ? "" : "s")"]
        if summary.alreadyHad > 0 { parts.append("\(summary.alreadyHad) already saved") }
        if summary.ignored > 0 { parts.append("\(summary.ignored) skipped") }
        return parts.joined(separator: " · ") + "."
    }
}
