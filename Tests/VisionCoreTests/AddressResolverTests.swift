import XCTest
@testable import VisionCore

/// Direct port of AddressResolverTest.kt's real cases (vision-android) —
/// the same "is this a URL or a search query" rule verified a third time,
/// now in Swift.
final class AddressResolverTests: XCTestCase {

    private let googleSearch = "https://www.google.com/search?q="

    func test_aFullHttpsUrl_isRecognizedAsDirect() {
        XCTAssertTrue(AddressResolver.isDirectUrl("https://example.com"))
    }

    func test_aFullHttpUrl_isRecognizedAsDirect() {
        XCTAssertTrue(AddressResolver.isDirectUrl("http://example.com/path"))
    }

    func test_aBareDomain_isRecognizedAsDirect() {
        XCTAssertTrue(AddressResolver.isDirectUrl("example.com"))
        XCTAssertTrue(AddressResolver.isDirectUrl("news.bbc.co.uk"))
    }

    func test_aBareDomainWithPath_isRecognizedAsDirect() {
        XCTAssertTrue(AddressResolver.isDirectUrl("example.com/some/path"))
    }

    func test_aBareDomainWithPort_isRecognizedAsDirect() {
        XCTAssertTrue(AddressResolver.isDirectUrl("example.com:8080"))
    }

    func test_aSingleWordHostWithNoDot_isNotDirect_evenWithAPort() {
        // Matches the desktop app's own regex exactly (it requires at least
        // one dot) — "localhost:3000" is genuinely ambiguous with URL
        // scheme syntax, so it's treated as a search query rather than
        // guessed.
        XCTAssertFalse(AddressResolver.isDirectUrl("localhost:3000"))
    }

    func test_aPlainSearchPhrase_isNotDirect() {
        XCTAssertFalse(AddressResolver.isDirectUrl("best pizza near me"))
    }

    func test_aPhraseContainingADotButWithSpaces_isNotDirect() {
        XCTAssertFalse(AddressResolver.isDirectUrl("what is 3.14 rounded"))
    }

    func test_aSingleWordWithNoDot_isNotDirect() {
        XCTAssertFalse(AddressResolver.isDirectUrl("weather"))
    }

    func test_resolveDestination_passesARealHttpsUrlThroughUnchanged() {
        XCTAssertEqual(
            AddressResolver.resolveDestination("https://example.com/page", searchEngineUrl: googleSearch),
            "https://example.com/page"
        )
    }

    func test_resolveDestination_addsHttpsToABareDomain() {
        XCTAssertEqual(AddressResolver.resolveDestination("example.com", searchEngineUrl: googleSearch), "https://example.com")
    }

    func test_resolveDestination_sendsASearchPhraseToTheConfiguredEngine_urlEncoded() {
        // Space becomes "%20" here vs. Kotlin's "+" (see AddressResolver's
        // doc comment) — same destination, different literal encoding.
        XCTAssertEqual(
            AddressResolver.resolveDestination("best pizza near me", searchEngineUrl: googleSearch),
            "\(googleSearch)best%20pizza%20near%20me"
        )
    }

    func test_resolveDestination_trimsSurroundingWhitespaceBeforeResolving() {
        XCTAssertEqual(AddressResolver.resolveDestination("  example.com  ", searchEngineUrl: googleSearch), "https://example.com")
    }

    func test_resolveDestination_respectsADifferentConfiguredSearchEngine() {
        let bing = "https://www.bing.com/search?q="
        XCTAssertEqual(AddressResolver.resolveDestination("cats", searchEngineUrl: bing), "\(bing)cats")
    }
}
