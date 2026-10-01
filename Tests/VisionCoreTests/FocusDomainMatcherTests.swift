import XCTest
@testable import VisionCore

/// Direct port of FocusDomainMatcherTest.kt's real cases.
final class FocusDomainMatcherTests: XCTestCase {
    private let blocklist = ["youtube.com", "instagram.com"]

    func test_exactDomainMatch() {
        XCTAssertEqual(FocusDomainMatcher.matchBlockedDomain(url: "https://youtube.com/watch?v=1", blockedDomains: blocklist), "youtube.com")
    }

    func test_subdomainMatchesTheParentBlockedDomain() {
        XCTAssertEqual(FocusDomainMatcher.matchBlockedDomain(url: "https://m.youtube.com/watch?v=1", blockedDomains: blocklist), "youtube.com")
    }

    func test_wwwPrefixIsNormalizedAway() {
        XCTAssertEqual(FocusDomainMatcher.matchBlockedDomain(url: "https://www.youtube.com", blockedDomains: blocklist), "youtube.com")
    }

    func test_anUnrelatedDomainDoesNotMatch() {
        XCTAssertNil(FocusDomainMatcher.matchBlockedDomain(url: "https://wikipedia.org", blockedDomains: blocklist))
    }

    func test_aDomainThatMerelyContainsABlockedWordAsASubstring_doesNotMatch() {
        // "notyoutube.com" ends with "youtube.com" as a raw string but is a
        // different real domain — the match must be on real subdomain
        // boundaries (a literal "." before the suffix), not substring search.
        XCTAssertNil(FocusDomainMatcher.matchBlockedDomain(url: "https://notyoutube.com", blockedDomains: blocklist))
    }

    func test_emptyBlocklistNeverMatches() {
        XCTAssertNil(FocusDomainMatcher.matchBlockedDomain(url: "https://youtube.com", blockedDomains: []))
    }

    func test_aMalformedUrlReturnsNoMatchRatherThanThrowing() {
        XCTAssertNil(FocusDomainMatcher.matchBlockedDomain(url: "not a url", blockedDomains: blocklist))
    }
}
