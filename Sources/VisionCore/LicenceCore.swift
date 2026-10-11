import Foundation
import CryptoKit

/// A signed licence certificate from VISION's licence server. Port of desktop's licenceCore.ts.
public struct LicenceCertificate: Equatable {
    public let licenceId: String
    public let org: String
    public let plan: String
    public let seats: Int
    public let installationId: String
    public let pricePerSyncCents: Int
    public let includedSyncs: Int
    public let expiresAt: Date?
    public let issuedAt: Date
    /// After this the app asks the server to renew the certificate; it keeps working in the meantime.
    public let renewAfter: Date
}

public enum LicenceState: Equatable {
    case none, active, renewDue, expired, otherDevice
}

public enum CertificateCheck: Equatable {
    case ok(LicenceCertificate, verified: Bool)
    case malformed
    case badSignature
}

/// Pure parts of the offline plug-in licence: reading and checking a signed certificate, deciding what state a
/// licence is in, and wording errors. The network and storage are in App/LicenceManager.swift.
public enum LicenceCore {
    /// Checks a certificate from the licence server: the signature (ECDSA P-256 / SHA-256 over the exact
    /// certificate bytes) against the public key built into the app, then reads it. With no public key
    /// configured (a development build) the signature can't be checked, and the result says so (`verified: false`).
    public static func readCertificate(certificate: String, signature: String, publicKey: String) -> CertificateCheck {
        guard let bytes = Data(base64Encoded: certificate) else { return .malformed }
        var verified = false
        if !publicKey.isEmpty {
            guard let keyData = Data(base64Encoded: publicKey),
                  let key = try? P256.Signing.PublicKey(derRepresentation: keyData),
                  let sigData = Data(base64Encoded: signature),
                  let sig = try? P256.Signing.ECDSASignature(derRepresentation: sigData),
                  key.isValidSignature(sig, for: bytes)
            else { return .badSignature }
            verified = true
        }
        guard let object = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              let licenceId = object["licenceId"] as? String,
              let org = object["org"] as? String,
              let installationId = object["installationId"] as? String,
              let issuedAt = (object["issuedAt"] as? NSNumber)?.doubleValue,
              let renewAfter = (object["renewAfter"] as? NSNumber)?.doubleValue
        else { return .malformed }
        let expires = (object["expiresAt"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue / 1000) }
        return .ok(
            LicenceCertificate(
                licenceId: licenceId, org: org, plan: object["plan"] as? String ?? "",
                seats: (object["seats"] as? NSNumber)?.intValue ?? 0, installationId: installationId,
                pricePerSyncCents: (object["pricePerSyncCents"] as? NSNumber)?.intValue ?? 0,
                includedSyncs: (object["includedSyncs"] as? NSNumber)?.intValue ?? 0,
                expiresAt: expires, issuedAt: Date(timeIntervalSince1970: issuedAt / 1000),
                renewAfter: Date(timeIntervalSince1970: renewAfter / 1000)
            ),
            verified: verified
        )
    }

    public static func state(of certificate: LicenceCertificate?, installationId: String, now: Date) -> LicenceState {
        guard let certificate else { return .none }
        if certificate.installationId != installationId { return .otherDevice }
        if let expires = certificate.expiresAt, expires <= now { return .expired }
        if now >= certificate.renewAfter { return .renewDue }
        return .active
    }

    /// Plain-language text for the codes the licence server answers with.
    public static func describe(error code: String) -> String {
        switch code {
        case "invalid_key": return "That licence key wasn't recognised. Check it and try again."
        case "licence_revoked": return "This licence has been withdrawn. Contact your administrator."
        case "licence_expired": return "This licence has expired. Contact your administrator to renew it."
        case "seat_limit_reached": return "All the devices on this licence are in use. Ask your administrator to free one up."
        case "not_activated": return "This device is no longer activated for the licence."
        case "offline": return "VISION couldn't reach the licence server. Check your connection and try again."
        default: return "Something went wrong. Please try again."
        }
    }

    /// Rand and cents for a price held in cents, e.g. 200 → "R2.00".
    public static func formatRand(cents: Int) -> String {
        String(format: "R%d.%02d", cents / 100, cents % 100)
    }

    /// What a month's syncs cost under a licence: those beyond the included allowance × the price.
    public static func billableSyncs(total: Int, included: Int) -> Int {
        max(0, total - included)
    }

    /// UTC calendar day, `YYYY-MM-DD` — the same day boundary the licence server bills on.
    public static func utcDay(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
}
