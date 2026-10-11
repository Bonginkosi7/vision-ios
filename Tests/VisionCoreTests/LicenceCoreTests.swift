import XCTest
@testable import VisionCore

/// The certificate below was made by the real licence server (vision-analytics-backend) — this proves an app
/// verifies exactly what the server signs.
final class LicenceCoreTests: XCTestCase {
    private let certificate = "eyJ2IjoxLCJsaWNlbmNlSWQiOiI1MTAyYTI4Ni01MmUwLTQ5YjYtYWY5YS0yYmE4NDBjNjc1MWUiLCJvcmciOiJUZXN0IE9yZyIsInBsYW4iOiJlbnRlcnByaXNlIiwic2VhdHMiOjMsImluc3RhbGxhdGlvbklkIjoiaW5zdGFsbC0xMjM0NTY3OCIsInByaWNlUGVyU3luY0NlbnRzIjoyMDAsImluY2x1ZGVkU3luY3MiOjUwLCJleHBpcmVzQXQiOjE4OTM0NTYwMDAwMDAsImlzc3VlZEF0IjoxNzkxNzA0MTA1MjY4LCJyZW5ld0FmdGVyIjoxNzk0Mjk2MTA1MjY4fQ=="
    private let signature = "MEUCIHLZI+1so5BUgMcaMaS2lWTD7WgHDn5XE4BwkfNRfDqvAiEA2DtxQ1EnV9VbuI5/2x4/E7EspOak+lYLDr+GQyeCLYM="
    private let publicKey = "MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEWFwXD5ko4GxJgPZcGY4gWg90ZJmMqC19rYOUzoH4esON5xnneo/BDY2YdTn0N42IUfzu5B9c63vILEgzb3rXeg=="

    func testACertificateSignedByTheServerIsAcceptedAndRead() {
        guard case let .ok(cert, verified) = LicenceCore.readCertificate(certificate: certificate, signature: signature, publicKey: publicKey) else {
            return XCTFail("the server's certificate should verify")
        }
        XCTAssertTrue(verified)
        XCTAssertEqual(cert.org, "Test Org")
        XCTAssertEqual(cert.seats, 3)
        XCTAssertEqual(cert.includedSyncs, 50)
        XCTAssertEqual(cert.pricePerSyncCents, 200)
        XCTAssertEqual(cert.installationId, "install-12345678")
        XCTAssertNotNil(cert.expiresAt)
        XCTAssertGreaterThan(cert.renewAfter, cert.issuedAt)
    }

    func testAChangedCertificateOrWrongKeyOrBadSignatureIsRefused() {
        let tampered = Data(base64Encoded: certificate).flatMap { String(data: $0, encoding: .utf8) }!
            .replacingOccurrences(of: "Test Org", with: "Other Org")
        let tamperedB64 = Data(tampered.utf8).base64EncodedString()
        XCTAssertEqual(LicenceCore.readCertificate(certificate: tamperedB64, signature: signature, publicKey: publicKey), .badSignature)
        XCTAssertEqual(LicenceCore.readCertificate(certificate: certificate, signature: "AAAA", publicKey: publicKey), .badSignature)
        XCTAssertEqual(LicenceCore.readCertificate(certificate: certificate, signature: signature, publicKey: "AAAA"), .badSignature)
    }

    func testWithNoPublicKeyTheCertificateIsReadButUnverified() {
        guard case let .ok(_, verified) = LicenceCore.readCertificate(certificate: certificate, signature: signature, publicKey: "") else {
            return XCTFail("should still be read")
        }
        XCTAssertFalse(verified)
    }

    func testACertificateMissingItsBasicsIsMalformed() {
        let bytes = Data("{\"org\":\"x\"}".utf8).base64EncodedString()
        XCTAssertEqual(LicenceCore.readCertificate(certificate: bytes, signature: "", publicKey: ""), .malformed)
        XCTAssertEqual(LicenceCore.readCertificate(certificate: "!!!", signature: "", publicKey: ""), .malformed)
    }

    private func cert(expires: Date? = nil, renewAfter: Date = Date(timeIntervalSince1970: 1000), installation: String = "me") -> LicenceCertificate {
        LicenceCertificate(licenceId: "l", org: "O", plan: "p", seats: 1, installationId: installation, pricePerSyncCents: 200,
                           includedSyncs: 0, expiresAt: expires, issuedAt: Date(timeIntervalSince1970: 0), renewAfter: renewAfter)
    }

    func testTheStateFollowsTheCertificate() {
        let now = Date(timeIntervalSince1970: 500)
        XCTAssertEqual(LicenceCore.state(of: nil, installationId: "me", now: now), .none)
        XCTAssertEqual(LicenceCore.state(of: cert(), installationId: "me", now: now), .active)
        XCTAssertEqual(LicenceCore.state(of: cert(), installationId: "me", now: Date(timeIntervalSince1970: 1500)), .renewDue)
        XCTAssertEqual(LicenceCore.state(of: cert(expires: Date(timeIntervalSince1970: 100)), installationId: "me", now: now), .expired)
        XCTAssertEqual(LicenceCore.state(of: cert(), installationId: "someone-else", now: now), .otherDevice)
    }

    func testHelpers() {
        XCTAssertEqual(LicenceCore.billableSyncs(total: 13, included: 5), 8)
        XCTAssertEqual(LicenceCore.billableSyncs(total: 3, included: 5), 0)
        XCTAssertEqual(LicenceCore.formatRand(cents: 200), "R2.00")
        XCTAssertEqual(LicenceCore.formatRand(cents: 2599), "R25.99")
        XCTAssertTrue(LicenceCore.describe(error: "seat_limit_reached").contains("devices"))
        XCTAssertTrue(LicenceCore.describe(error: "???").contains("went wrong"))
        XCTAssertEqual(LicenceCore.utcDay(Date(timeIntervalSince1970: 1_791_763_140)), "2026-10-11")
        XCTAssertEqual(LicenceCore.utcDay(Date(timeIntervalSince1970: 1_791_763_260)), "2026-10-12")
    }
}
