import Foundation

public enum EduPlanActivityType: String, Codable, CaseIterable, Equatable {
    case flashcards = "FLASHCARDS"
    case mockTest = "MOCK_TEST"
    case reviewWeakTopic = "REVIEW_WEAK_TOPIC"
    case readMaterial = "READ_MATERIAL"
}

public struct GeneratedPlanItem: Equatable {
    public let dayOffset: Int
    public let topicId: String?
    public let activityType: EduPlanActivityType
    public let targetCount: Int
    public let rationale: String
    public init(dayOffset: Int, topicId: String?, activityType: EduPlanActivityType, targetCount: Int, rationale: String) {
        self.dayOffset = dayOffset; self.topicId = topicId; self.activityType = activityType
        self.targetCount = targetCount; self.rationale = rationale
    }
}

/// Direct port of StudyPlanGenerator.kt (itself a port of desktop's
/// planGenerator.ts) — same deterministic, rules-based weekly plan
/// generation (no AI call, per desktop's own confirmed V1 scope: "a
/// well-designed rules-based system is acceptable"). 5 weekday sessions
/// allocated across a student's real level-1 topics proportional to a
/// mastery/exam-phase-derived weight (via the largest-remainder method,
/// so integer slot counts sum exactly), plus one always-appended
/// mock-test session once real topics exist to build a plan around.
public enum StudyPlanGenerator {
    private enum Phase { case steady, finalReview, consolidation, broadCoverage }

    private static let sessionsPerWeek = 5
    private static let flashcardTarget = 10
    private static let reviewTarget = 5
    private static let mockTestTarget = 10
    private static let dayInterval: TimeInterval = 24 * 60 * 60

    private static func phaseFor(examDate: Date?, weekStartAt: Date) -> (phase: Phase, daysToExam: Int?) {
        guard let examDate else { return (.steady, nil) }
        let daysToExam = Int((examDate.timeIntervalSince(weekStartAt) / dayInterval).rounded(.up))
        let phase: Phase
        if daysToExam <= 7 { phase = .finalReview }
        else if daysToExam <= 21 { phase = .consolidation }
        else { phase = .broadCoverage }
        return (phase, daysToExam)
    }

    /// weak=3, developing=2, notAssessed=2.5 (an initial pass matters, but
    /// a known weakness matters more), strong=1 — except in finalReview,
    /// where strong topics get zero weight (no time wasted on what's
    /// already mastered days before an exam).
    private static func weight(for topic: TopicMastery, phase: Phase) -> Double {
        if phase == .finalReview && topic.status == .strong { return 0 }
        switch topic.status {
        case .weak: return 3.0
        case .notAssessed: return 2.5
        case .developing: return 2.0
        case .strong: return 1.0
        }
    }

    private struct WeightedTopic { let topic: TopicMastery; let weight: Double }
    private struct AllocatedTopic { let topic: TopicMastery; let weight: Double; let count: Int }

    /// Largest-remainder method — guarantees the integer per-topic slot
    /// counts sum to exactly `totalSlots`, proportional to weight.
    private static func allocateSlots(_ weighted: [WeightedTopic], totalSlots: Int) -> [AllocatedTopic] {
        let active = weighted.filter { $0.weight > 0 }
        let sumWeights = active.reduce(0) { $0 + $1.weight }
        guard !active.isEmpty, sumWeights > 0 else { return [] }

        struct WithFloor { let topic: TopicMastery; let weight: Double; let floor: Int; let remainder: Double }
        let withFloor: [WithFloor] = active.map { wt in
            let exact = (wt.weight / sumWeights) * Double(totalSlots)
            let flr = Int(exact.rounded(.down))
            return WithFloor(topic: wt.topic, weight: wt.weight, floor: flr, remainder: exact - Double(flr))
        }

        var counts: [String: Int] = [:]
        for w in withFloor { counts[w.topic.topicId] = w.floor }
        var remaining = totalSlots - withFloor.reduce(0) { $0 + $1.floor }

        let byRemainder = withFloor.sorted { a, b in
            if a.remainder != b.remainder { return a.remainder > b.remainder }
            return a.weight > b.weight
        }
        var i = 0
        while i < byRemainder.count && remaining > 0 {
            let key = byRemainder[i].topic.topicId
            counts[key] = (counts[key] ?? 0) + 1
            remaining -= 1
            i += 1
        }

        return withFloor.compactMap { w in
            let count = counts[w.topic.topicId] ?? w.floor
            return count > 0 ? AllocatedTopic(topic: w.topic, weight: w.weight, count: count) : nil
        }
    }

    private static func rationale(for topic: TopicMastery, phase: Phase, daysToExam: Int?) -> String {
        if topic.status == .weak { return "Weak topic (\(topic.masteryPercent)% mastery) — prioritized early this week." }
        if topic.status == .notAssessed { return "Not yet assessed — an initial pass to establish a real mastery baseline." }
        if phase == .finalReview, let daysToExam { return "Exam in \(daysToExam) day\(daysToExam == 1 ? "" : "s") — final review on your lower-mastery topics." }
        if topic.status == .developing { return "Developing (\(topic.masteryPercent)% mastery) — steady reinforcement." }
        return "Strong (\(topic.masteryPercent)% mastery) — light reinforcement to keep it that way."
    }

    public static func generateWeeklyPlan(topics: [TopicMastery], examDate: Date?, weekStartAt: Date) -> [GeneratedPlanItem] {
        let (phase, daysToExam) = phaseFor(examDate: examDate, weekStartAt: weekStartAt)
        let weighted = topics.map { WeightedTopic(topic: $0, weight: weight(for: $0, phase: phase)) }
        let allocation = allocateSlots(weighted, totalSlots: sessionsPerWeek)
        let ordered = allocation.sorted { $0.weight > $1.weight }

        var slots: [TopicMastery] = []
        for allocated in ordered {
            for _ in 0..<allocated.count { slots.append(allocated.topic) }
        }

        var items: [GeneratedPlanItem] = slots.enumerated().map { dayOffset, topic in
            let isWeakish = topic.status == .weak || topic.status == .developing
            return GeneratedPlanItem(
                dayOffset: dayOffset, topicId: topic.topicId,
                activityType: isWeakish ? .reviewWeakTopic : .flashcards,
                targetCount: isWeakish ? reviewTarget : flashcardTarget,
                rationale: rationale(for: topic, phase: phase, daysToExam: daysToExam)
            )
        }

        if !items.isEmpty {
            let mockTestDay: Int
            if phase == .finalReview, let daysToExam {
                mockTestDay = min(max(daysToExam - 1, 0), sessionsPerWeek - 1)
            } else {
                mockTestDay = sessionsPerWeek - 1
            }
            let rationaleText: String
            if let daysToExam {
                rationaleText = "Exam in \(daysToExam) day\(daysToExam == 1 ? "" : "s") — a full practice test to check real readiness."
            } else {
                rationaleText = "A full practice test across this week's material to check real readiness."
            }
            items.append(GeneratedPlanItem(dayOffset: mockTestDay, topicId: nil, activityType: .mockTest, targetCount: mockTestTarget, rationale: rationaleText))
        }

        return items
    }
}
