import XCTest
@testable import VisionCore

final class FlashcardGenerationLogicTests: XCTestCase {
    private let topics = [TopicRef(id: "t1", name: "Photosynthesis")]

    func test_parsesARealWellFormedFlashcardsResponse() {
        let json = """
        {"flashcards":[{"front":"What is photosynthesis?","back":"The process plants use to convert light into energy.","topicName":"Photosynthesis"},{"front":"Where does it occur?","back":"In the chloroplasts."}]}
        """
        let cards = FlashcardGenerationLogic.parseFlashcards(json, topics: topics)
        XCTAssertEqual(cards?.count, 2)
        XCTAssertEqual(cards?[0].front, "What is photosynthesis?")
        XCTAssertEqual(cards?[0].topicId, "t1")
        XCTAssertNil(cards?[1].topicId)
    }

    func test_dropsACardWithAnEmptyFrontOrBack() {
        let json = """
        {"flashcards":[{"front":"","back":"should be dropped"},{"front":"Real question","back":"Real answer"},{"front":"Missing back","back":""}]}
        """
        let cards = FlashcardGenerationLogic.parseFlashcards(json, topics: [])
        XCTAssertEqual(cards?.count, 1)
        XCTAssertEqual(cards?.first?.front, "Real question")
    }

    func test_returnsNilForGenuinelyMalformedJson() {
        XCTAssertNil(FlashcardGenerationLogic.parseFlashcards("not json", topics: []))
    }

    func test_clampCount_staysWithinRealBounds() {
        XCTAssertEqual(FlashcardGenerationLogic.clampCount(0), 1)
        XCTAssertEqual(FlashcardGenerationLogic.clampCount(10), 10)
        XCTAssertEqual(FlashcardGenerationLogic.clampCount(999), 50)
    }

    func test_systemInstruction_includesTheRequestedCountAndTopicFragment() {
        let instruction = FlashcardGenerationLogic.systemInstruction(count: 7, topics: topics)
        XCTAssertTrue(instruction.contains("exactly 7 flashcards"))
        XCTAssertTrue(instruction.contains("- Photosynthesis"))
    }
}
