import Foundation

public enum TaskCategory: String, Codable, CaseIterable {
    case learn = "LEARN"
    case research = "RESEARCH"
    case create = "CREATE"
    case plan = "PLAN"
    case work = "WORK"
    case general = "GENERAL"

    public var label: String {
        switch self {
        case .learn: return "Learn"
        case .research: return "Research"
        case .create: return "Create"
        case .plan: return "Plan"
        case .work: return "Work"
        case .general: return "General"
        }
    }
}

/// Direct port of the classification half of ChatCategoryLogic.kt
/// (itself a port of desktop's classifyTask.ts) — local, rule-based task
/// classification. Deliberately not a second LLM call pretending to be
/// deep understanding: plain keyword/pattern matching, free and instant,
/// shown to the user as exactly that (a label, not a claim of
/// comprehension). Ordered checks, first match wins.
///
/// Android's OFFLINE category (triggered by "save/download ... offline"
/// phrasing, offering a quick "Save for offline" action tied to a URL in
/// the message) and its live-page-fetch/Memory-facts context
/// (`extractUrl`/`extractMemoryCandidate`/`FetchLivePage`/stored Memory)
/// are deliberately NOT ported — this app has no hidden-WKWebView
/// content-fetch capability or Memory feature yet (see README's
/// disclosed scope trim), so there's nothing real for an OFFLINE
/// category or a "remember this" candidate to attach to. The remaining
/// six categories classify and answer the same way without either.
public enum ChatCategoryLogic {
    // Same bounding instinct as every other AI call site in this app
    // (e.g. TutorLogic's own, separately-defined maxHistoryMessages) —
    // caps token/cost growth on a long conversation.
    public static let maxHistoryMessages = 20

    private static let categoryPatterns: [(TaskCategory, String)] = [
        (.learn, #"\b(explain|teach|learn|understand|what is|what are|how does|how do|study|revise|revision|quiz me|test me)\b"#),
        (.research, #"\b(research|compare|comparison|find out|look into|investigate|sources?|evidence)\b"#),
        (.create, #"\b(write|draft|compose|rewrite|edit|essay|email|letter|caption|post|script|outline)\b"#),
        (.plan, #"\b(plan|schedule|itinerary|agenda|timeline|organize my|checklist)\b"#),
        (.work, #"\b(meeting|brief|report|memo|presentation|client|colleague|deadline|proposal|pitch)\b"#),
    ]

    public static func classify(_ message: String) -> TaskCategory {
        let lower = message.lowercased()
        for (category, pattern) in categoryPatterns {
            if lower.range(of: pattern, options: .regularExpression) != nil {
                return category
            }
        }
        return .general
    }

    private static let baseInstruction = "You are VISION, an offline-capable browser assistant. Be direct and genuinely useful. Never claim to have browsed the live web, saved a file, or done anything you have not actually done in this response."

    private static func taskInstruction(_ category: TaskCategory) -> String {
        switch category {
        case .learn: return baseInstruction + " The user wants to learn or understand something — explain it clearly, at an appropriate level, using examples where they help."
        case .work: return baseInstruction + " The user is working on something professional (a meeting, brief, report, or similar) — be concise, structured, and practical."
        case .research: return baseInstruction + " The user wants to research or compare something. VISION has no open-ended web search or live page-fetching here — answer from your own training knowledge and be explicit that you haven't searched the open web."
        case .create: return baseInstruction + " The user wants help writing or drafting something — produce a genuinely usable draft, and ask a clarifying question first only if the request is too ambiguous to attempt."
        case .plan: return baseInstruction + " The user wants help planning or organizing something — give a clear, structured plan or checklist."
        case .general: return baseInstruction
        }
    }

    public static func buildSystemInstruction(category: TaskCategory) -> String {
        taskInstruction(category)
    }

    public static func trimmedHistory(_ history: [ChatMessage]) -> [ChatMessage] {
        Array(history.suffix(maxHistoryMessages))
    }
}

/// Direct port of ChatSessionDbHelper.kt's deriveSessionTitle — a
/// session's title is always just the real first message, trimmed and
/// truncated — no second AI call pretending to summarize it, same
/// discipline as the classification above.
public enum ChatSessionTitle {
    private static let maxLength = 48

    public static func derive(fromFirstMessage firstMessage: String) -> String {
        let collapsed = firstMessage.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        if collapsed.isEmpty { return "New chat" }
        if collapsed.count <= maxLength { return collapsed }
        return String(collapsed.prefix(maxLength)) + "…"
    }
}
