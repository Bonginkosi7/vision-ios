import Foundation

/// Direct port of RewardRules.kt's real category/event/points scale —
/// carried over as-is from the desktop app's rewardRules.ts, not resized
/// independently. `RewardEventType` only lists the real event types whose
/// trigger already exists on iOS (OfflineSaver, TaskStore, FocusManager,
/// WellbeingActions) — Android's own EDU_TEST_COMPLETED/
/// STUDY_PLAN_TASK_COMPLETED/STUDY_SESSION_COMPLETED/EDU_MASTERY_MILESTONE
/// cases are left out for exactly the same reason Android's own
/// RewardRules.kt documents leaving them out "through Phase 18 because
/// Study Plan didn't exist yet to trigger them": no education feature
/// exists on iOS yet to genuinely trigger them. Add them when the
/// matching iOS phase (Study Materials/Flashcards/Exams/Study Plan) lands,
/// not before.
public enum RewardCategory: String, Codable, CaseIterable {
    case health = "HEALTH"
    case learning = "LEARNING"
    case productivity = "PRODUCTIVITY"
    case consistency = "CONSISTENCY"

    public var label: String {
        switch self {
        case .health: return "Health"
        case .learning: return "Learning"
        case .productivity: return "Productivity"
        case .consistency: return "Consistency"
        }
    }
}

public enum RewardDedupe: Equatable {
    case oncePerDay
    case onceEver
}

public struct RewardRule: Equatable {
    public let category: RewardCategory
    public let points: Int
    public let label: String
    public let dedupe: RewardDedupe?
    public let dailyLimit: Int?

    public init(category: RewardCategory, points: Int, label: String, dedupe: RewardDedupe? = nil, dailyLimit: Int? = nil) {
        self.category = category
        self.points = points
        self.label = label
        self.dedupe = dedupe
        self.dailyLimit = dailyLimit
    }
}

public enum RewardEventType: String, Codable, CaseIterable {
    case offlinePrep = "OFFLINE_PREP"
    case taskCompleted = "TASK_COMPLETED"
    case healthyBreak = "HEALTHY_BREAK"
    case digitalBalance = "DIGITAL_BALANCE"
    case focusSessionCompleted = "FOCUS_SESSION_COMPLETED"
    case weeklyConsistency = "WEEKLY_CONSISTENCY"

    public var rule: RewardRule {
        switch self {
        case .offlinePrep:
            return RewardRule(category: .productivity, points: 5, label: "Save a page for offline use", dailyLimit: 20)
        case .taskCompleted:
            return RewardRule(category: .productivity, points: 5, label: "Complete a planned task", dailyLimit: 5)
        case .healthyBreak:
            return RewardRule(category: .health, points: 10, label: "Take a break after 10+ minutes of continuous activity", dailyLimit: 3)
        case .digitalBalance:
            return RewardRule(category: .health, points: 10, label: "Keep a balanced day (your first real break of the day)", dedupe: .oncePerDay)
        case .focusSessionCompleted:
            return RewardRule(category: .productivity, points: 15, label: "Complete a Focus Session (15+ min, run to the end)", dailyLimit: 4)
        case .weeklyConsistency:
            return RewardRule(category: .consistency, points: 20, label: "Stay active on 4+ different days in a week", dedupe: .onceEver)
        }
    }
}

/// Real point-value scale ported as-is from the desktop app (rewardRules.ts).
public enum RewardRules {
    public static let levelSize = 150
    public static let levelNames = [
        "Getting Started", "Building Habits", "Finding Balance",
        "Staying Consistent", "In Control", "Focused", "VISIONARY",
    ]

    public static func levelName(_ level: Int) -> String {
        levelNames[max(0, min(level, levelNames.count) - 1)]
    }

    public static let categoryInsightTemplates: [RewardCategory: String] = [
        .health: "Your most valuable habit this week was taking healthy breaks.",
        .learning: "Your most valuable habit this week was learning — lessons, reviews, and practice.",
        .productivity: "Your most valuable habit this week was staying productive — focus sessions and completed tasks.",
        .consistency: "Your most valuable habit this week was showing up consistently.",
    ]
}
