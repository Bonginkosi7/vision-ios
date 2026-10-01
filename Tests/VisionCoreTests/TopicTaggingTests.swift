import XCTest
@testable import VisionCore

/// Direct port of TopicTaggingTest.kt's real cases.
final class TopicTaggingTests: XCTestCase {
    private let topics = [
        TopicRef(id: "t1", name: "Algebra"),
        TopicRef(id: "t2", name: "Geometry"),
    ]

    func test_promptFragment_isEmptyWhenTheDocumentHasNoRealExtractedTopics() {
        XCTAssertEqual(TopicTagging.promptFragment([]), "")
    }

    func test_promptFragment_listsRealTopicNamesVerbatim() {
        let fragment = TopicTagging.promptFragment(topics)
        XCTAssertTrue(fragment.contains("- Algebra"))
        XCTAssertTrue(fragment.contains("- Geometry"))
    }

    func test_resolveTopicId_matchesARealTopicNameCaseInsensitively() {
        XCTAssertEqual(TopicTagging.resolveTopicId("algebra", topics), "t1")
        XCTAssertEqual(TopicTagging.resolveTopicId("Geometry", topics), "t2")
    }

    func test_resolveTopicId_trimsSurroundingWhitespace() {
        XCTAssertEqual(TopicTagging.resolveTopicId("  Algebra  ", topics), "t1")
    }

    func test_anAiInventedNameNotInTheRealList_resolvesToNil() {
        XCTAssertNil(TopicTagging.resolveTopicId("Trigonometry", topics))
    }

    func test_nilOrBlankTopicName_resolvesToNil() {
        XCTAssertNil(TopicTagging.resolveTopicId(nil, topics))
        XCTAssertNil(TopicTagging.resolveTopicId("   ", topics))
    }
}
