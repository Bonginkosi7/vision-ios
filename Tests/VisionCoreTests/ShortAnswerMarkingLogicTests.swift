import XCTest
@testable import VisionCore

final class ShortAnswerMarkingLogicTests: XCTestCase {
    private let pending = [
        PendingShortAnswer(questionId: "q1", prompt: "What is 2+2?", modelAnswer: "4", studentAnswer: "four"),
        PendingShortAnswer(questionId: "q2", prompt: "Capital of France?", modelAnswer: "Paris", studentAnswer: ""),
    ]

    func test_prompt_includesEachQuestionAndPlaceholderForEmptyAnswer() {
        let prompt = ShortAnswerMarkingLogic.prompt(for: pending)
        XCTAssertTrue(prompt.contains("(0) Question: What is 2+2?"))
        XCTAssertTrue(prompt.contains("(1) Question: Capital of France?"))
        XCTAssertTrue(prompt.contains("(no answer given)"))
    }

    func test_parseMarkings_mapsIndexBackToRealQuestionId() {
        let json = """
        {"markings":[{"questionIndex":0,"isCorrect":true,"feedback":"Correct, four is right."},{"questionIndex":1,"isCorrect":false,"feedback":""}]}
        """
        let markings = ShortAnswerMarkingLogic.parseMarkings(json, pending: pending)
        XCTAssertEqual(markings?.count, 2)
        XCTAssertEqual(markings?[0].questionId, "q1")
        XCTAssertEqual(markings?[1].feedback, "Not quite right.")
    }

    func test_parseMarkings_returnsNilForMalformedJson() {
        XCTAssertNil(ShortAnswerMarkingLogic.parseMarkings("garbage", pending: pending))
    }

    func test_parseMarkings_dropsOutOfRangeIndex() {
        XCTAssertNil(ShortAnswerMarkingLogic.parseMarkings("{\"markings\":[{\"questionIndex\":9,\"isCorrect\":true}]}", pending: pending))
    }
}
