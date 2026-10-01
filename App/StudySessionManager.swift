import Foundation
import VisionCore

struct StartSessionResult {
    let session: StudySession
    let masteryBeforePercent: Int?
}

struct CompleteSessionResult {
    let session: StudySession?
    let masteryBeforePercent: Int?
    let masteryAfterPercent: Int?
}

/// Real study-session lifecycle — direct port of StudySessionLogic.kt
/// (itself the Android counterpart of desktop's startStudySession/
/// completeStudySession). A session's real value is the before/after
/// mastery delta and the real reward it unlocks on completion, both
/// computed from genuine flashcard-review/exam-answer events via
/// `PerformanceCalculator`, never estimated.
struct StudySessionManager {
    let studyPlanStore: StudyPlanStore
    let performanceCalculator: PerformanceCalculator
    let topicStore: TopicStore
    let rewardEngine: RewardEngine

    func startSession(documentId: String?, topicId: String?, activityType: EduPlanActivityType, planItemId: String?) -> StartSessionResult {
        let session = (try? studyPlanStore.startSession(documentId: documentId, topicId: topicId, activityType: activityType, planItemId: planItemId))
            ?? StudySession(id: UUID().uuidString, documentId: documentId, topicId: topicId, activityType: activityType, planItemId: planItemId, startedAt: Date(), endedAt: nil, confidenceRating: nil)
        let masteryBeforePercent = topicId.flatMap { performanceCalculator.masteryForTopic($0)?.masteryPercent }
        return StartSessionResult(session: session, masteryBeforePercent: masteryBeforePercent)
    }

    /// Recomputes the same topic's mastery after whatever studying
    /// happened during the session — genuinely recomputed from the real
    /// events recorded in between, never estimated. Awards points for
    /// the real completion itself (a scheduled plan task if this session
    /// came from one, otherwise a genuine ad hoc study session), plus
    /// the separate one-time `eduMasteryMilestone` bonus the first time a
    /// topic's status flips into "strong".
    func completeSession(sessionId: String, confidenceRating: Int?, masteryBeforePercent: Int?) -> CompleteSessionResult {
        let priorSession = (try? studyPlanStore.getSession(sessionId)) ?? nil
        let session = (try? studyPlanStore.completeSession(sessionId, confidenceRating: confidenceRating)) ?? nil
        if let planItemId = session?.planItemId {
            try? studyPlanStore.markItemCompleted(planItemId)
        }

        let topicId = priorSession?.topicId ?? session?.topicId
        let topicName = topicId.flatMap { (try? topicStore.get($0)) ?? nil }?.name
        let after = topicId.flatMap { performanceCalculator.masteryForTopic($0) }

        if session?.planItemId != nil {
            let note = "Completed a scheduled study-plan task" + (topicName.map { " — \($0)" } ?? "")
            rewardEngine.awardIfEligible(type: .studyPlanTaskCompleted, note: note)
        } else {
            let note = "Completed a study session" + (topicName.map { " — \($0)" } ?? "")
            rewardEngine.awardIfEligible(type: .studySessionCompleted, note: note)
        }

        if let after, after.status == .strong, let topicId {
            let note = "Reached strong mastery" + (topicName.map { " in \($0)" } ?? "")
            rewardEngine.awardIfEligible(type: .eduMasteryMilestone, note: note, dedupeKey: "edu_mastery_milestone:\(topicId)")
        }

        return CompleteSessionResult(session: session, masteryBeforePercent: masteryBeforePercent, masteryAfterPercent: after?.masteryPercent)
    }
}
