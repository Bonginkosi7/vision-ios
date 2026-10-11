import XCTest
@testable import VisionCore

final class BookmarkImportTests: XCTestCase {
    private let chromeExport = """
    <!DOCTYPE NETSCAPE-Bookmark-file-1>
    <META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
    <TITLE>Bookmarks</TITLE>
    <H1>Bookmarks</H1>
    <DL><p>
        <DT><H3 ADD_DATE="1" PERSONAL_TOOLBAR_FOLDER="true">Bookmarks bar</H3>
        <DL><p>
            <DT><A HREF="https://example.com/" ADD_DATE="1">Example &amp; Co</A>
            <DT><H3>Reading</H3>
            <DL><p>
                <DT><A HREF="https://news.example.org/a?x=1&amp;y=2">News &quot;A&quot;</A>
                <DT><A HREF="javascript:alert(1)">Bookmarklet</A>
            </DL><p>
            <DT><A HREF="https://example.com/">Duplicate</A>
        </DL><p>
        <DT><H3>Other bookmarks</H3>
        <DL><p>
            <DT><A HREF="http://plain.example.net/">Plain</A>
            <DT><A HREF="place:sort=8">Firefox query</A>
        </DL><p>
    </DL><p>
    """

    func testLinksAndFoldersAreReadFromAChromeStyleExport() {
        let parsed = BookmarkImport.parse(html: chromeExport)
        XCTAssertEqual(parsed[0], ImportedBookmark(url: "https://example.com/", title: "Example & Co", folder: ""))
        XCTAssertEqual(parsed[1], ImportedBookmark(url: "https://news.example.org/a?x=1&y=2", title: "News \"A\"", folder: "Reading"))
        XCTAssertEqual(parsed[2].url, "javascript:alert(1)")
        XCTAssertEqual(parsed[4], ImportedBookmark(url: "http://plain.example.net/", title: "Plain", folder: ""))
    }

    func testThePlanSkipsNonWebAddressesRepeatsAndWhatVisionAlreadyHas() {
        let result = BookmarkImport.plan(BookmarkImport.parse(html: chromeExport)) { $0 == "http://plain.example.net/" }
        XCTAssertEqual(result.toAdd.map(\.url), ["https://example.com/", "https://news.example.org/a?x=1&y=2"])
        XCTAssertEqual(result.summary, BookmarkImportSummary(added: 2, alreadyHad: 1, ignored: 3))
    }

    func testABookmarkWithoutATitleUsesItsAddress() {
        XCTAssertEqual(BookmarkImport.parse(html: "<DL><DT><A HREF=\"https://a.com/\"></A></DL>")[0].title, "https://a.com/")
    }

    func testSingleQuotesAndLowerCaseTagsWork() {
        let parsed = BookmarkImport.parse(html: "<dl><dt><h3>Work</h3><dl><dt><a href='https://a.com/x'>A</a></dl></dl>")
        XCTAssertEqual(parsed, [ImportedBookmark(url: "https://a.com/x", title: "A", folder: "Work")])
    }

    func testNestedFoldersUseTheInnermostNameAndAnEmptyFileIsEmpty() {
        let html = "<DL><DT><H3>Outer</H3><DL><DT><H3>Inner</H3><DL><DT><A HREF='https://a.com'>A</A></DL><DT><A HREF='https://b.com'>B</A></DL></DL>"
        let parsed = BookmarkImport.parse(html: html)
        XCTAssertEqual(parsed[0].folder, "Inner")
        XCTAssertEqual(parsed[1].folder, "Outer")
        XCTAssertTrue(BookmarkImport.parse(html: "<html><body>nothing</body></html>").isEmpty)
    }

    func testEntitiesAreDecoded() {
        XCTAssertEqual(BookmarkImport.decodeEntities("a &amp; b &lt;c&gt; &#39;d&#39; &#x41; &unknown;"), "a & b <c> 'd' A &unknown;")
    }

    func testTheSummarySentenceReadsNaturally() {
        XCTAssertEqual(BookmarkImport.describe(BookmarkImportSummary(added: 0, alreadyHad: 0, ignored: 0)), "No bookmarks were found in that file.")
        XCTAssertEqual(BookmarkImport.describe(BookmarkImportSummary(added: 1, alreadyHad: 0, ignored: 0)), "Imported 1 bookmark.")
        XCTAssertEqual(BookmarkImport.describe(BookmarkImportSummary(added: 12, alreadyHad: 3, ignored: 2)), "Imported 12 bookmarks · 3 already saved · 2 skipped.")
    }
}
