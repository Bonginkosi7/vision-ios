import XCTest
@testable import VisionCore

final class CertificateErrorLogicTests: XCTestCase {
    func testOnlyCertificateCodesAreCertificateErrors() {
        XCTAssertTrue(CertificateErrorLogic.isCertificateError(code: -1202))
        XCTAssertTrue(CertificateErrorLogic.isCertificateError(code: -1201))
        XCTAssertFalse(CertificateErrorLogic.isCertificateError(code: -1009)) // not connected to the internet
        XCTAssertFalse(CertificateErrorLogic.isCertificateError(code: -1001)) // timed out
    }

    func testReasonsAreSpecificAndHaveAFallback() {
        XCTAssertTrue(CertificateErrorLogic.reason(forCode: -1201).contains("expired"))
        XCTAssertTrue(CertificateErrorLogic.reason(forCode: -1204).contains("isn't valid yet"))
        XCTAssertTrue(CertificateErrorLogic.reason(forCode: -999).contains("-999"))
    }

    func testEscapeHTMLNeutralisesMarkup() {
        XCTAssertEqual(CertificateErrorLogic.escapeHTML("<b a=\"1\">&"), "&lt;b a=&quot;1&quot;&gt;&amp;")
    }

    func testExceptionsAreKeyedByHostAndCertificate() {
        let store = CertificateExceptionStore()
        XCTAssertFalse(store.isAccepted(host: "a.com", fingerprint: "f1"))
        store.record(host: "A.com", fingerprint: "f1")
        XCTAssertTrue(store.isAccepted(host: "a.com", fingerprint: "f1"))
        XCTAssertFalse(store.isAccepted(host: "a.com", fingerprint: "f2"))
        XCTAssertFalse(store.isAccepted(host: "b.com", fingerprint: "f1"))
    }
}
