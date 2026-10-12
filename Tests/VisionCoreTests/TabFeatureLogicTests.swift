import XCTest
@testable import VisionCore

final class TranslateLogicTests: XCTestCase {
    func test_buildsTranslateGoogAddress() throws {
        let out = try XCTUnwrap(TranslateLogic.translatedURL(for: "https://example.com/a/b?x=1#top", targetCode: "fr"))
        XCTAssertTrue(out.hasPrefix("https://example-com.translate.goog/a/b?x=1&_x_tr_sl=auto&_x_tr_tl=fr&_x_tr_hl=fr&_x_tr_pto=wapp"), out)
        XCTAssertTrue(out.hasSuffix("#top"), out)
    }

    func test_realHyphensAreDoubledSoTheHostCanBeRecovered() throws {
        let out = try XCTUnwrap(TranslateLogic.translatedURL(for: "https://my-site.co.uk/", targetCode: "es"))
        XCTAssertTrue(out.hasPrefix("https://my--site-co-uk.translate.goog/"), out)
        XCTAssertEqual(TranslateLogic.originalURL(of: out), "https://my-site.co.uk/")
    }

    func test_roundTripKeepsThePagesOwnQuery() throws {
        let original = "https://news.example.org/story/42?ref=home&lang=en#c3"
        let translated = try XCTUnwrap(TranslateLogic.translatedURL(for: original, targetCode: "zu"))
        XCTAssertTrue(TranslateLogic.isTranslated(translated))
        XCTAssertEqual(TranslateLogic.originalURL(of: translated), original)
    }

    func test_refusesPagesItCannotTranslate() {
        for bad in ["http://example.com/", "https://example.com:8443/", "https://localhost/", "https://192.168.1.5/",
                    "https://printer.local/", "file:///tmp/x.html", "not a url", "https://example-com.translate.goog/",
                    "https://\(String(repeating: "a", count: 70)).com/"] {
            XCTAssertNil(TranslateLogic.translatedURL(for: bad, targetCode: "en"), bad)
        }
    }

    func test_onlyTranslateGoogAddressesCountAsTranslated() {
        XCTAssertFalse(TranslateLogic.isTranslated("https://example.com/"))
        XCTAssertFalse(TranslateLogic.isTranslated("https://evil.com/?u=x.translate.goog"))
        XCTAssertNil(TranslateLogic.originalURL(of: "https://example.com/"))
        XCTAssertNil(TranslateLogic.originalURL(of: "garbage"))
    }

    func test_targetCodes() {
        XCTAssertEqual(TranslateLogic.targetCode(languageCode: "fr"), "fr")
        XCTAssertEqual(TranslateLogic.targetCode(languageCode: "zh", script: "Hans"), "zh-CN")
        XCTAssertEqual(TranslateLogic.targetCode(languageCode: "zh", script: "Hant"), "zh-TW")
        XCTAssertEqual(TranslateLogic.targetCode(languageCode: nil), "en")
        XCTAssertEqual(TranslateLogic.targetCode(languageCode: "he"), "iw")
    }
}

final class PinnedTabsTests: XCTestCase {
    func test_pinnedFirstKeepsEachGroupsOrder() {
        let items = [("a", false), ("b", true), ("c", false), ("d", true)]
        XCTAssertEqual(PinnedTabs.pinnedFirst(items, isPinned: { $0.1 }).map(\.0), ["b", "d", "a", "c"])
    }

    func test_sanitizeKeepsWebAddressesAndDropsTheRest() {
        let cleaned = PinnedTabs.sanitize([
            "https://mail.example.com/", "https://mail.example.com/", "  https://news.example.org/a ",
            "about:blank", "javascript:alert(1)", "file:///etc/passwd", "",
        ])
        XCTAssertEqual(cleaned, ["https://mail.example.com/", "https://news.example.org/a"])
    }

    func test_sanitizeCapsTheCount() {
        let many = (0..<40).map { "https://site\($0).example.com/" }
        XCTAssertEqual(PinnedTabs.sanitize(many).count, PinnedTabs.maxCount)
    }

    func test_isPinnable() {
        XCTAssertTrue(PinnedTabs.isPinnable("https://example.com"))
        XCTAssertFalse(PinnedTabs.isPinnable("vision://newtab"))
        XCTAssertFalse(PinnedTabs.isPinnable(""))
    }
}

final class SplitLayoutTests: XCTestCase {
    func test_axisFollowsAvailableRoom() {
        XCTAssertEqual(SplitLayout.axis(width: 393, height: 700), .stacked)       // iPhone portrait
        XCTAssertEqual(SplitLayout.axis(width: 852, height: 393), .sideBySide)    // iPhone landscape
        XCTAssertEqual(SplitLayout.axis(width: 820, height: 1180), .sideBySide)   // iPad portrait
        XCTAssertEqual(SplitLayout.axis(width: 1180, height: 820), .sideBySide)   // iPad landscape
        XCTAssertEqual(SplitLayout.axis(width: 507, height: 700), .stacked)       // iPad narrow Split View
    }

    func test_clampKeepsBothPanesUsable() {
        XCTAssertEqual(SplitLayout.clamp(0), SplitLayout.minRatio)
        XCTAssertEqual(SplitLayout.clamp(2), SplitLayout.maxRatio)
        XCTAssertEqual(SplitLayout.clamp(.nan), SplitLayout.defaultRatio)
    }

    func test_firstPaneAndDividerRoundTrip() {
        let extent = 1010.0
        XCTAssertEqual(SplitLayout.firstPaneLength(extent: extent, ratio: 0.5), 500)
        let ratio = SplitLayout.ratio(forDividerAt: 505, extent: extent)
        XCTAssertEqual(ratio, 0.5, accuracy: 0.001)
        XCTAssertEqual(SplitLayout.ratio(forDividerAt: -40, extent: extent), SplitLayout.minRatio)
        XCTAssertEqual(SplitLayout.ratio(forDividerAt: 9999, extent: extent), SplitLayout.maxRatio)
    }
}

final class AddressDisplayTests: XCTestCase {
    func test_showsJustTheSite() {
        XCTAssertEqual(AddressDisplay.text(for: "https://en.wikipedia.org/wiki/Hello_world"), "en.wikipedia.org")
        XCTAssertEqual(AddressDisplay.text(for: "https://www.bbc.com/news/articles/cj5y?at_medium=RSS"), "bbc.com")
        XCTAssertEqual(AddressDisplay.text(for: "http://Example.COM:8080/a"), "example.com")
    }

    func test_translatedPageShowsItsOriginalSite() {
        let translated = TranslateLogic.translatedURL(for: "https://www.bbc.com/news/a", targetCode: "en") ?? ""
        XCTAssertEqual(AddressDisplay.text(for: translated), "bbc.com")
    }

    func test_savedPagesAndOddAddresses() {
        XCTAssertEqual(AddressDisplay.text(for: "file:///var/mobile/x.webarchive"), AddressDisplay.savedPageLabel)
        XCTAssertEqual(AddressDisplay.text(for: ""), "")
        XCTAssertEqual(AddressDisplay.text(for: "about:blank"), "about:blank")
        XCTAssertEqual(AddressDisplay.text(for: "  https://example.org/  "), "example.org")
    }
}
