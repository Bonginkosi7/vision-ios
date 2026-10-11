import Foundation

/// The explanation shown on VISION's certificate-error page — port of desktop's certificateErrors.ts and
/// Android's SslErrorLogic.kt, keyed on iOS's own URLError codes (a different platform, a different real
/// error surface). Only errors this can explain accurately get a specific sentence.
public enum CertificateErrorLogic {
    /// URLError codes that mean "the server's certificate can't be trusted" (NSURLErrorDomain).
    public static let certificateErrorCodes: Set<Int> = [
        -1200, // secureConnectionFailed
        -1201, // serverCertificateHasBadDate
        -1202, // serverCertificateUntrusted
        -1203, // serverCertificateHasUnknownRoot
        -1204, // serverCertificateNotYetValid
    ]

    public static func isCertificateError(code: Int) -> Bool { certificateErrorCodes.contains(code) }

    public static func reason(forCode code: Int) -> String {
        switch code {
        case -1201: return "This site's security certificate has expired or has an invalid date."
        case -1202: return "This site's security certificate isn't issued by a trusted authority."
        case -1203: return "This site's security certificate was issued by an authority this device doesn't know."
        case -1204: return "This site's security certificate isn't valid yet."
        case -1200: return "A secure connection to this site couldn't be made."
        default: return "This site's security certificate couldn't be verified (error code \(code))."
        }
    }

    public static func errorName(forCode code: Int) -> String {
        switch code {
        case -1200: return "secureConnectionFailed"
        case -1201: return "serverCertificateHasBadDate"
        case -1202: return "serverCertificateUntrusted"
        case -1203: return "serverCertificateHasUnknownRoot"
        case -1204: return "serverCertificateNotYetValid"
        default: return "error \(code)"
        }
    }

    /// The page's text is untrusted (hostnames and certificate names come from the network), so it is escaped.
    public static func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

/// Certificate-error exceptions the user accepted — kept in memory only, never written to disk, so a full
/// restart asks again (the conservative default, same as desktop and Android). Keyed by host plus the
/// certificate's own fingerprint, so a different certificate for the same host asks again.
public final class CertificateExceptionStore {
    public static let shared = CertificateExceptionStore()
    private var accepted = Set<String>()
    private let lock = NSLock()

    public init() {}

    private func key(host: String, fingerprint: String) -> String { "\(host.lowercased())|\(fingerprint)" }

    public func record(host: String, fingerprint: String) {
        lock.lock(); defer { lock.unlock() }
        accepted.insert(key(host: host, fingerprint: fingerprint))
    }

    public func isAccepted(host: String, fingerprint: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return accepted.contains(key(host: host, fingerprint: fingerprint))
    }
}
