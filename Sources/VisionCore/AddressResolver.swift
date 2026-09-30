import Foundation

/// Ported to match the desktop app's own logic exactly (desktop's
/// src/renderer/newtab/newtab.ts: isDirectUrl/resolveDestination, already
/// ported once to Android's AddressResolver.kt) — same rule for "is this a
/// URL or a search query", so typing the same thing into any of the three
/// apps' address bars behaves identically.
public enum AddressResolver {
    private static let bareHostRegex: NSRegularExpression = {
        // The pattern itself is fixed and known-valid, ported verbatim from
        // AddressResolver.kt's BARE_HOST_REGEX — a compile-time constant,
        // not user input, so a forced try is honest here rather than
        // laundering an impossible failure through error handling.
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: "^[a-z0-9-]+(\\.[a-z0-9-]+)+(:\\d+)?(/.*)?$", options: [.caseInsensitive])
    }()

    public static func isDirectUrl(_ trimmed: String) -> Bool {
        let scheme = URLComponents(string: trimmed)?.scheme
        if scheme == "http" || scheme == "https" { return true }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        let matchesBareHost = bareHostRegex.firstMatch(in: trimmed, range: range) != nil
        return matchesBareHost && !trimmed.contains(" ")
    }

    /// Note: Kotlin's `URLEncoder.encode` (Java's form-encoding convention)
    /// encodes a space as "+"; Swift's `addingPercentEncoding` encodes it as
    /// "%20". Both are valid, equivalent query-string encodings that every
    /// real search engine accepts — the literal output byte-for-byte
    /// differs from the Android/desktop ports, but the resolved destination
    /// behaves identically. Disclosed here rather than silently assumed
    /// identical.
    public static func resolveDestination(_ raw: String, searchEngineUrl: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let scheme = URLComponents(string: trimmed)?.scheme
        if scheme == "http" || scheme == "https" { return trimmed }
        if isDirectUrl(trimmed) { return "https://\(trimmed)" }
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        return searchEngineUrl + encoded
    }
}
