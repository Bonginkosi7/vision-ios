import XCTest
@testable import VisionCore

final class NewsLogicTests: XCTestCase {
    func test_parsesTitleLinkPubDateAndThumbnailFromARealShapedItem() {
        let xml = """
        <rss><channel>
        <item>
            <title><![CDATA[World leaders meet in Geneva]]></title>
            <link>https://www.bbc.co.uk/news/world-12345678</link>
            <pubDate>Thu, 25 Sep 2026 08:00:00 GMT</pubDate>
            <media:thumbnail width="144" height="81" url="https://ichef.bbci.co.uk/news/144/thumb.jpg"/>
        </item>
        </channel></rss>
        """

        let items = NewsLogic.parseHeadlines(xml: xml, limit: 20)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "World leaders meet in Geneva")
        XCTAssertEqual(items[0].url, "https://www.bbc.co.uk/news/world-12345678")
        XCTAssertEqual(items[0].source, "BBC News")
        XCTAssertEqual(items[0].publishedAt, "Thu, 25 Sep 2026 08:00:00 GMT")
        XCTAssertEqual(items[0].thumbnailURL, "https://ichef.bbci.co.uk/news/144/thumb.jpg")
    }

    func test_itemWithoutAThumbnailStillParsesWithANilThumbnailURL() {
        let xml = """
        <item>
            <title>Plain headline</title>
            <link>https://www.bbc.co.uk/news/world-1</link>
            <pubDate>Thu, 25 Sep 2026 08:00:00 GMT</pubDate>
        </item>
        """

        let items = NewsLogic.parseHeadlines(xml: xml, limit: 20)

        XCTAssertEqual(items.count, 1)
        XCTAssertNil(items[0].thumbnailURL)
    }

    func test_decodesHTMLEntitiesInTitles() {
        let xml = """
        <item>
            <title>Rock &amp; roll &quot;legend&quot; turns 80</title>
            <link>https://www.bbc.co.uk/news/world-2</link>
        </item>
        """

        let items = NewsLogic.parseHeadlines(xml: xml, limit: 20)

        XCTAssertEqual(items[0].title, "Rock & roll \"legend\" turns 80")
    }

    func test_itemMissingALinkIsSkippedRatherThanFabricated() {
        let xml = """
        <item>
            <title>No link here</title>
        </item>
        """

        XCTAssertTrue(NewsLogic.parseHeadlines(xml: xml, limit: 20).isEmpty)
    }

    func test_multipleItemsAreAllParsedInOrder() {
        let xml = """
        <item><title>First</title><link>https://www.bbc.co.uk/news/1</link></item>
        <item><title>Second</title><link>https://www.bbc.co.uk/news/2</link></item>
        <item><title>Third</title><link>https://www.bbc.co.uk/news/3</link></item>
        """

        let items = NewsLogic.parseHeadlines(xml: xml, limit: 20)

        XCTAssertEqual(items.map(\.title), ["First", "Second", "Third"])
    }

    func test_emptyFeedReturnsEmptyListNeverFabricatedHeadlines() {
        XCTAssertTrue(NewsLogic.parseHeadlines(xml: "<rss><channel></channel></rss>", limit: 20).isEmpty)
    }

    func test_respectsTheLimitParameter() {
        let xml = """
        <item><title>First</title><link>https://www.bbc.co.uk/news/1</link></item>
        <item><title>Second</title><link>https://www.bbc.co.uk/news/2</link></item>
        <item><title>Third</title><link>https://www.bbc.co.uk/news/3</link></item>
        """

        XCTAssertEqual(NewsLogic.parseHeadlines(xml: xml, limit: 2).map(\.title), ["First", "Second"])
    }
}
