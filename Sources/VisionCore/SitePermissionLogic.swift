import Foundation

/// What a web page can ask to use that VISION remembers a per-site answer for. iOS's web engine only asks the app
/// about the camera and microphone (it handles a page's location request itself), so those are the two kinds here —
/// nothing else is faked with an invented dialog.
public enum SitePermissionKind: String, CaseIterable, Sendable {
    case camera, microphone

    public var label: String {
        switch self {
        case .camera: return "camera"
        case .microphone: return "microphone"
        }
    }
}

public enum SitePermissionLogic {
    public enum Resolution: Equatable, Sendable { case grant, deny, ask }

    /// What to do with a request for `kinds`: any remembered "block" blocks it; if every kind was remembered as
    /// "allow" it is granted; otherwise the person is asked.
    public static func resolve(kinds: [SitePermissionKind], remembered: (SitePermissionKind) -> Bool?) -> Resolution {
        var needsAsking = false
        for kind in kinds {
            switch remembered(kind) {
            case .some(false): return .deny
            case .none: needsAsking = true
            case .some(true): break
            }
        }
        return needsAsking ? .ask : .grant
    }

    /// "example.com wants to use your camera and microphone."
    public static func promptText(host: String, kinds: [SitePermissionKind]) -> String {
        let names = kinds.map(\.label)
        let list = names.count == 2 ? "\(names[0]) and \(names[1])" : (names.first ?? "device")
        return "\(host) wants to use your \(list)."
    }

    /// The page's origin as stored — scheme, host and a non-default port ("https://example.com"). Nil when it isn't a web origin.
    public static func origin(scheme: String, host: String, port: Int) -> String? {
        let scheme = scheme.lowercased(), host = host.lowercased()
        guard scheme == "http" || scheme == "https", !host.isEmpty else { return nil }
        let isDefault = port <= 0 || (scheme == "https" && port == 443) || (scheme == "http" && port == 80)
        return isDefault ? "\(scheme)://\(host)" : "\(scheme)://\(host):\(port)"
    }
}
