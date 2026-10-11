import XCTest
@testable import VisionCore

final class AutofillLogicTests: XCTestCase {
    func testOriginOfKeepsSchemeHostAndPort() {
        XCTAssertEqual(AutofillLogic.originOf("https://Example.com/login?x=1"), "https://example.com")
        XCTAssertEqual(AutofillLogic.originOf("http://localhost:3000/a"), "http://localhost:3000")
        XCTAssertNil(AutofillLogic.originOf("file:///etc/passwd"))
        XCTAssertNil(AutofillLogic.originOf("not a url"))
        XCTAssertNil(AutofillLogic.originOf("vision://app/settings"))
    }

    func testDifferentSubdomainOrSchemeIsADifferentOrigin() {
        XCTAssertNotEqual(AutofillLogic.originOf("https://example.com"), AutofillLogic.originOf("https://evil.example.com"))
        XCTAssertNotEqual(AutofillLogic.originOf("https://example.com"), AutofillLogic.originOf("http://example.com"))
    }

    func testNormalizedOriginAcceptsABareHost() {
        XCTAssertEqual(AutofillLogic.normalizedOrigin("  example.com "), "https://example.com")
        XCTAssertEqual(AutofillLogic.normalizedOrigin("http://example.com/path"), "http://example.com")
        XCTAssertNil(AutofillLogic.normalizedOrigin(""))
    }

    func testFillScriptEncodesHostileValuesSafely() {
        let script = AutofillLogic.buildFillScript(username: "a\"b</script>", password: "p\\w'\n")
        XCTAssertTrue(script.contains("\"a\\\"b<\\/script>\"") || script.contains("\"a\\\"b</script>\""))
        XCTAssertFalse(script.contains("a\"b</script>"))
        XCTAssertTrue(script.contains("var usernameJson = "))
    }

    func testFillScriptWithoutUsernameSkipsIt() {
        XCTAssertTrue(AutofillLogic.buildFillScript(username: nil, password: "x").contains("var usernameJson = null;"))
    }
}
