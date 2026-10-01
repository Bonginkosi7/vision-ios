import XCTest
@testable import VisionCore

final class TopicExtractionLogicTests: XCTestCase {
    func test_parsesARealWellFormedTopicsResponse() {
        let json = """
        {"topics":[{"name":"Photosynthesis","summary":"How plants convert light to energy.","subtopics":[{"name":"Light reactions","summary":"Happen in the thylakoid."}]},{"name":"Cellular respiration","summary":"How cells release energy.","subtopics":[]}]}
        """
        let topics = TopicExtractionLogic.parseTopics(json)
        XCTAssertEqual(topics?.count, 2)
        XCTAssertEqual(topics?[0].name, "Photosynthesis")
        XCTAssertEqual(topics?[0].subtopics.count, 1)
        XCTAssertEqual(topics?[0].subtopics[0].name, "Light reactions")
        XCTAssertEqual(topics?[1].subtopics.count, 0)
    }

    func test_dropsATopicWithAnEmptyName() {
        let json = """
        {"topics":[{"name":"","summary":"should be dropped"},{"name":"Real topic","summary":"kept"}]}
        """
        let topics = TopicExtractionLogic.parseTopics(json)
        XCTAssertEqual(topics?.count, 1)
        XCTAssertEqual(topics?.first?.name, "Real topic")
    }

    func test_returnsNilForGenuinelyMalformedJson() {
        XCTAssertNil(TopicExtractionLogic.parseTopics("not json at all"))
    }

    func test_returnsNilWhenEveryTopicIsDropped() {
        let json = """
        {"topics":[{"name":""},{"name":"   "}]}
        """
        XCTAssertNil(TopicExtractionLogic.parseTopics(json))
    }

    func test_boundedText_trimsToMaxCharsAndWhitespace() {
        let longText = String(repeating: "a", count: 20_000)
        let bounded = TopicExtractionLogic.boundedText(longText)
        XCTAssertEqual(bounded.count, 12_000)
    }
}

final class StructuredJSONTests: XCTestCase {
    func test_extractsJsonFromARealFencedBlock() {
        let raw = "Here you go:\n```json\n{\"a\":1}\n```\nHope that helps."
        XCTAssertEqual(StructuredJSON.extractJsonText(raw), "{\"a\":1}")
    }

    func test_extractsFromAFenceWithNoJsonLanguageTag() {
        let raw = "```\n{\"a\":1}\n```"
        XCTAssertEqual(StructuredJSON.extractJsonText(raw), "{\"a\":1}")
    }

    func test_returnsTheTrimmedRawTextWhenThereIsNoFence() {
        let raw = "  {\"a\":1}  "
        XCTAssertEqual(StructuredJSON.extractJsonText(raw), "{\"a\":1}")
    }
}
