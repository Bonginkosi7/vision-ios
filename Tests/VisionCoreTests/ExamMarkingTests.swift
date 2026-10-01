import XCTest
@testable import VisionCore

final class ExamMarkingTests: XCTestCase {
    func test_isCorrect_matchesCaseInsensitiveAndTrimmed() {
        XCTAssertTrue(ExamMarking.isCorrect(studentAnswer: "  paris  ", correctAnswer: "Paris"))
        XCTAssertFalse(ExamMarking.isCorrect(studentAnswer: "London", correctAnswer: "Paris"))
    }

    func test_describeCorrectAnswer_resolvesMcqIndexToOptionText() {
        XCTAssertEqual(ExamMarking.describeCorrectAnswer(type: "mcq", correctAnswer: "1", options: ["A", "B", "C"]), "B")
    }

    func test_describeCorrectAnswer_fallsBackWhenIndexOutOfRange() {
        XCTAssertEqual(ExamMarking.describeCorrectAnswer(type: "mcq", correctAnswer: "9", options: ["A", "B"]), "9")
    }

    func test_describeCorrectAnswer_passesThroughForTrueFalse() {
        XCTAssertEqual(ExamMarking.describeCorrectAnswer(type: "true_false", correctAnswer: "true", options: nil), "true")
    }

    func test_scorePercent_computesRealPercentage() {
        XCTAssertEqual(ExamMarking.scorePercent(correctCount: 3, totalAnswers: 4), 75.0)
        XCTAssertEqual(ExamMarking.scorePercent(correctCount: 0, totalAnswers: 0), 0.0)
    }
}
