import XCTest
@testable import VisionCore

final class StudyPlanGeneratorTests: XCTestCase {
    private let weekStart = Date()

    private func topic(_ id: String, status: MasteryStatus, percent: Int = 50) -> TopicMastery {
        TopicMastery(topicId: id, name: id, level: 1, parentTopicId: nil, sampleCount: 5, masteryPercent: percent, status: status, lastActivityAt: nil)
    }

    func test_singleWeakTopic_getsAllFiveSlotsPlusAMockTest() {
        let items = StudyPlanGenerator.generateWeeklyPlan(topics: [topic("w1", status: .weak)], examDate: nil, weekStartAt: weekStart)
        XCTAssertEqual(items.count, 6)
        XCTAssertEqual(items.filter { $0.activityType == .reviewWeakTopic }.count, 5)
        XCTAssertEqual(items.filter { $0.activityType == .mockTest }.count, 1)
        XCTAssertEqual(items.first { $0.activityType == .mockTest }?.dayOffset, 4)
        XCTAssertEqual(items.first { $0.activityType == .reviewWeakTopic }?.targetCount, 5)
    }

    func test_weakAndStrongMixed_splitsSlotsByLargestRemainder() {
        let items = StudyPlanGenerator.generateWeeklyPlan(topics: [topic("w1", status: .weak), topic("s1", status: .strong)], examDate: nil, weekStartAt: weekStart)
        let nonMock = items.filter { $0.activityType != .mockTest }
        XCTAssertEqual(nonMock.count, 5)
        XCTAssertEqual(nonMock.filter { $0.topicId == "w1" }.count, 4)
        XCTAssertEqual(nonMock.filter { $0.topicId == "s1" }.count, 1)
        XCTAssertEqual(nonMock.first?.topicId, "w1", "the heavier-weighted topic should be ordered into the earliest days")
        XCTAssertEqual(items.first { $0.topicId == "s1" }?.activityType, .flashcards)
    }

    func test_finalReviewPhase_excludesStrongTopicsFromAllocation() {
        let examDate = weekStart.addingTimeInterval(5 * 24 * 60 * 60)
        let items = StudyPlanGenerator.generateWeeklyPlan(topics: [topic("w1", status: .weak), topic("s1", status: .strong)], examDate: examDate, weekStartAt: weekStart)
        XCTAssertFalse(items.contains { $0.topicId == "s1" && $0.activityType != .mockTest })
        XCTAssertEqual(items.filter { $0.topicId == "w1" }.count, 5)
        let mockItem = items.first { $0.activityType == .mockTest }
        XCTAssertEqual(mockItem?.dayOffset, 4)
        XCTAssertTrue(mockItem?.rationale.contains("Exam in 5 days") == true)
    }

    func test_finalReviewWithOnlyAStrongTopic_producesZeroItems() {
        let examDate = weekStart.addingTimeInterval(5 * 24 * 60 * 60)
        let items = StudyPlanGenerator.generateWeeklyPlan(topics: [topic("s1", status: .strong)], examDate: examDate, weekStartAt: weekStart)
        XCTAssertTrue(items.isEmpty, "nothing to schedule and nothing to test, so no fabricated mock test either")
    }

    func test_rationaleWording_matchesEachRealMasteryStatus() {
        XCTAssertTrue(StudyPlanGenerator.generateWeeklyPlan(topics: [topic("w1", status: .weak, percent: 40)], examDate: nil, weekStartAt: weekStart).first { $0.topicId == "w1" }?.rationale.contains("Weak topic (40% mastery)") == true)
        XCTAssertTrue(StudyPlanGenerator.generateWeeklyPlan(topics: [topic("n1", status: .notAssessed, percent: 0)], examDate: nil, weekStartAt: weekStart).first { $0.topicId == "n1" }?.rationale.contains("establish a real mastery baseline") == true)
        XCTAssertTrue(StudyPlanGenerator.generateWeeklyPlan(topics: [topic("d1", status: .developing, percent: 70)], examDate: nil, weekStartAt: weekStart).first { $0.topicId == "d1" }?.rationale.contains("Developing (70% mastery)") == true)
        let strongRationale = StudyPlanGenerator.generateWeeklyPlan(topics: [topic("s1", status: .strong, percent: 95), topic("w1", status: .weak)], examDate: nil, weekStartAt: weekStart).first { $0.topicId == "s1" }?.rationale
        XCTAssertTrue(strongRationale?.contains("Strong (95% mastery)") == true)
    }

    func test_zeroTopics_producesZeroItems() {
        XCTAssertTrue(StudyPlanGenerator.generateWeeklyPlan(topics: [], examDate: nil, weekStartAt: weekStart).isEmpty)
    }
}
