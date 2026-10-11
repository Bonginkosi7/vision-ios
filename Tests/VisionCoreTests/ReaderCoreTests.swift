import XCTest
@testable import VisionCore

final class ReaderCoreTests: XCTestCase {
    private func article(title: String = "A <b>title</b>") -> ReaderArticle {
        ReaderArticle(id: "1", sourceURL: "https://www.example.com/post", title: title, byline: "Ann", siteName: "", content: "<p>Body</p>", lang: "en", dir: "", minutes: 2)
    }

    func testOnlyWebPagesCanBeOpenedInReaderView() {
        XCTAssertTrue(ReaderCore.canRead(url: "https://example.com/post"))
        XCTAssertTrue(ReaderCore.canRead(url: "http://example.com"))
        XCTAssertFalse(ReaderCore.canRead(url: "file:///tmp/a.html"))
        XCTAssertFalse(ReaderCore.canRead(url: "about:blank"))
        XCTAssertFalse(ReaderCore.canRead(url: ""))
    }

    func testReadingTimeIsAtLeastAMinuteAndScalesWithLength() {
        XCTAssertEqual(ReaderCore.readingMinutes(textLength: 0), 1)
        XCTAssertEqual(ReaderCore.readingMinutes(textLength: 500), 1)
        XCTAssertEqual(ReaderCore.readingMinutes(textLength: 13_110), 10)
    }

    func testTheExtractionResultIsParsedDefensively() {
        XCTAssertNil(ReaderCore.parseExtraction(nil, id: "1", sourceURL: "https://a.com"))
        XCTAssertNil(ReaderCore.parseExtraction("not json", id: "1", sourceURL: "https://a.com"))
        XCTAssertNil(ReaderCore.parseExtraction("{\"content\":\"   \"}", id: "1", sourceURL: "https://a.com"))
        let parsed = ReaderCore.parseExtraction("{\"title\":\"T\",\"content\":\"<p>Hi</p>\",\"textLength\":40,\"byline\":\"A\"}", id: "1", sourceURL: "https://a.com")
        XCTAssertEqual(parsed?.title, "T")
        XCTAssertEqual(parsed?.byline, "A")
        XCTAssertEqual(parsed?.siteName, "")
        XCTAssertEqual(ReaderCore.parseExtraction("{\"content\":\"<p>x</p>\"}", id: "1", sourceURL: "https://a.com/x")?.title, "https://a.com/x")
    }

    func testTheExtractionScriptEmbedsTheLibraryAndReturnsJSONOrNull() {
        let script = ReaderCore.buildExtractionScript(readabilitySource: "function Readability(){}")
        XCTAssertTrue(script.contains("function Readability(){}"))
        XCTAssertTrue(script.contains("JSON.stringify"))
        XCTAssertTrue(script.contains("return null"))
    }

    func testTheReadingDocumentAllowsNoScriptsAndEscapesTheTitle() {
        let doc = ReaderCore.buildDocument(article: article(), prefs: ReaderPrefs())
        XCTAssertTrue(doc.contains("default-src 'none'"))
        XCTAssertFalse(doc.contains("script-src"))
        XCTAssertTrue(doc.contains("A &lt;b&gt;title&lt;/b&gt;"))
        XCTAssertTrue(doc.contains("Ann · example.com · 2 min read"))
        XCTAssertTrue(doc.contains("<p>Body</p>"))
    }

    func testTextSizeAndTypefaceFollowThePreferences() {
        XCTAssertTrue(ReaderCore.buildDocument(article: article(), prefs: ReaderPrefs(scalePercent: 150, serif: false)).contains("font-size: 28.5px"))
        XCTAssertTrue(ReaderCore.buildDocument(article: article(), prefs: ReaderPrefs(scalePercent: 100, serif: true)).contains("Georgia"))
        XCTAssertEqual(ReaderCore.clampScale(300), 200)
        XCTAssertEqual(ReaderCore.clampScale(10), 80)
        XCTAssertEqual(ReaderCore.clampScale(104), 100)
        XCTAssertEqual(ReaderPrefs(scalePercent: 999).scalePercent, 200)
    }
}
