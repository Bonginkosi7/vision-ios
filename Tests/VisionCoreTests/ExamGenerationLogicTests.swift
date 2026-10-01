import XCTest
@testable import VisionCore

final class ExamGenerationLogicTests: XCTestCase {
    private let topics = [TopicRef(id: "t1", name: "Photosynthesis")]

    func test_systemInstruction_includesRequestedCountsAndTopicFragment() {
        let counts = ExamGenerationCounts(mcq: 2, trueFalse: 1, shortAnswer: 1)
        let instruction = ExamGenerationLogic.systemInstruction(counts: counts, topics: topics)
        XCTAssertTrue(instruction.contains("exactly 2 multiple-choice questions, 1 true/false questions, and 1 short-answer questions"))
        XCTAssertTrue(instruction.contains("- Photosynthesis"))
    }

    func test_parsesARealWellFormedMixedResponseAndDropsInvalidQuestions() {
        let json = """
        {"questions":[
          {"type":"mcq","prompt":"2+2?","options":["3","4","5"],"correctOptionIndex":1,"explanation":"math","topicName":"Photosynthesis"},
          {"type":"true_false","prompt":"Sky is blue","correctAnswer":"TRUE","explanation":"obvious"},
          {"type":"short_answer","prompt":"Explain X","modelAnswer":"X is Y","explanation":"because"},
          {"type":"mcq","prompt":"too few options","options":["only one"],"correctOptionIndex":0},
          {"type":"unknown_type","prompt":"should be dropped"}
        ]}
        """
        let questions = ExamGenerationLogic.parseQuestions(json, topics: topics)
        XCTAssertEqual(questions?.count, 3)
        XCTAssertEqual(questions?[0].correctAnswer, "1")
        XCTAssertEqual(questions?[0].topicId, "t1")
        XCTAssertEqual(questions?[1].correctAnswer, "true")
        XCTAssertEqual(questions?[2].correctAnswer, "X is Y")
    }

    func test_parseQuestions_returnsNilForMalformedOrEmptyJson() {
        XCTAssertNil(ExamGenerationLogic.parseQuestions("not json", topics: []))
        XCTAssertNil(ExamGenerationLogic.parseQuestions("{\"questions\":[]}", topics: []))
    }

    func test_boundedText_trimsWhitespace() {
        XCTAssertEqual(ExamGenerationLogic.boundedText("  hello world  "), "hello world")
    }

    func test_counts_total_sumsAllThreeTypes() {
        XCTAssertEqual(ExamGenerationCounts(mcq: 2, trueFalse: 1, shortAnswer: 1).total, 4)
    }
}
