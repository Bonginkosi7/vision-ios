import Foundation

/// What the address bar shows while it isn't being edited: just the site, like Safari ("en.wikipedia.org"), not the
/// whole address. Tapping the bar shows the full address to edit.
public enum AddressDisplay {
    public static let savedPageLabel = "Saved page"

    public static func text(for url: String) -> String {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        // A translated page shows the site it came from, not Google's translate.goog address.
        if let original = TranslateLogic.originalURL(of: trimmed) { return text(for: original) }
        guard let comps = URLComponents(string: trimmed), let scheme = comps.scheme?.lowercased() else { return trimmed }
        switch scheme {
        case "http", "https":
            guard var host = comps.host?.lowercased(), !host.isEmpty else { return trimmed }
            if host.hasPrefix("www.") { host.removeFirst(4) }
            return host
        case "file":
            return savedPageLabel
        default:
            return trimmed
        }
    }
}
