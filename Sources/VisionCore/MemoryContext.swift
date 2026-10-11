import Foundation

/// The block appended to Ask VISION's instructions when the user has told VISION to remember things —
/// same wording as desktop's buildMemoryContext (classifyTask.ts).
public enum MemoryContext {
    /// Most facts sent with one question, newest kept — bounds the prompt (and the on-device model's small window).
    public static let maxFacts = 20

    public static func build(facts: [String]) -> String? {
        let recent = facts.suffix(maxFacts)
        if recent.isEmpty { return nil }
        let lines = recent.map { "- \($0)" }.joined(separator: "\n")
        return "The user has explicitly told VISION to remember the following about them (real, user-authored facts — never inferred or guessed):\n\(lines)\nUse this if relevant to personalize your answer; don't force it into unrelated questions."
    }
}
