import Foundation

/// "Translate page" uses Google Translate's website proxy: a page at
/// https://example.com/a becomes https://example-com.translate.goog/a?_x_tr_sl=auto&_x_tr_tl=fr…
/// Pure string work, mirroring desktop's src/shared/translate.ts.
///
/// Privacy: translating a page sends its address — and Google then fetches the
/// page itself — to Google. It only ever happens when the user asks for it.
public enum TranslateLogic {
    static let suffix = ".translate.goog"
    static let maxDNSLabel = 63

    /// The code Google Translate uses for a language the user's device is set to ("zh" with a Traditional script is "zh-TW").
    public static func targetCode(languageCode: String?, script: String? = nil) -> String {
        let code = (languageCode ?? "").lowercased()
        switch code {
        case "": return "en"
        case "zh": return script?.lowercased() == "hant" ? "zh-TW" : "zh-CN"
        case "he": return "iw"
        default: return code
        }
    }

    public static func isTranslated(_ urlString: String) -> Bool {
        (URLComponents(string: urlString)?.host ?? "").lowercased().hasSuffix(suffix)
    }

    /// The translated address for a page, or nil when this kind of page can't be translated
    /// (not https, a custom port, a bare/IP/local host, already translated).
    public static func translatedURL(for pageURL: String, targetCode: String) -> String? {
        guard let comps = URLComponents(string: pageURL), comps.scheme?.lowercased() == "https", comps.port == nil,
              let rawHost = comps.host?.lowercased() else { return nil }
        guard rawHost.contains("."), !rawHost.hasSuffix(suffix), !rawHost.hasSuffix(".local"), !rawHost.contains(":"),
              rawHost.contains(where: { $0.isLetter }) else { return nil }

        let label = rawHost.replacingOccurrences(of: "-", with: "--").replacingOccurrences(of: ".", with: "-")
        guard label.count <= maxDNSLabel else { return nil }

        var out = URLComponents()
        out.scheme = "https"
        out.host = label + suffix
        out.percentEncodedPath = comps.percentEncodedPath.isEmpty ? "/" : comps.percentEncodedPath
        var items = (comps.percentEncodedQueryItems ?? []).filter { !$0.name.hasPrefix("_x_tr_") }
        items.append(contentsOf: [
            URLQueryItem(name: "_x_tr_sl", value: "auto"),
            URLQueryItem(name: "_x_tr_tl", value: targetCode),
            URLQueryItem(name: "_x_tr_hl", value: targetCode),
            URLQueryItem(name: "_x_tr_pto", value: "wapp"),
        ])
        out.percentEncodedQueryItems = items
        out.percentEncodedFragment = comps.percentEncodedFragment
        return out.string
    }

    /// The original page behind a Google-translated address, or nil when it isn't one.
    public static func originalURL(of translated: String) -> String? {
        guard let comps = URLComponents(string: translated), let host = comps.host?.lowercased(), host.hasSuffix(suffix) else { return nil }
        let label = String(host.dropLast(suffix.count))
        guard !label.isEmpty else { return nil }

        let original = label
            .replacingOccurrences(of: "--", with: "\u{0}")
            .replacingOccurrences(of: "-", with: ".")
            .replacingOccurrences(of: "\u{0}", with: "-")
        var out = URLComponents()
        out.scheme = "https"
        out.host = original
        out.percentEncodedPath = comps.percentEncodedPath
        let kept = (comps.percentEncodedQueryItems ?? []).filter { !$0.name.hasPrefix("_x_tr_") }
        out.percentEncodedQueryItems = kept.isEmpty ? nil : kept
        out.percentEncodedFragment = comps.percentEncodedFragment
        return out.string
    }
}
