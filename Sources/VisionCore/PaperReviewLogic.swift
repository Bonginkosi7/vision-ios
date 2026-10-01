import Foundation

public struct GrammarIssue: Equatable {
    public let original: String
    public let suggestion: String
    public let explanation: String
    public init(original: String, suggestion: String, explanation: String) {
        self.original = original; self.suggestion = suggestion; self.explanation = explanation
    }
}

public struct PaperReview: Equatable {
    public let grammarIssues: [GrammarIssue]
    public let improvementSuggestions: [String]
    /// One honest, clearly-labeled AI opinion on the writing itself —
    /// never a claim of having checked this text against any database or
    /// the internet, since this app has neither. Deliberately NOT a
    /// plagiarism-detection result.
    public let originalityNote: String
    public init(grammarIssues: [GrammarIssue], improvementSuggestions: [String], originalityNote: String) {
        self.grammarIssues = grammarIssues; self.improvementSuggestions = improvementSuggestions; self.originalityNote = originalityNote
    }
}

/// Pure prompt-building/parsing half of real AI-backed paper review —
/// direct port of PaperReviewLogic.kt (itself the Android counterpart of
/// desktop's reviewPaper). Never a fabricated plagiarism-database match,
/// since this app has no corpus or web access to check against — the
/// instruction explicitly tells the model to say only what it can
/// genuinely observe in the text. The actual network call lives in
/// App/PaperReviewer.swift, same real/pure split as every other AI
/// feature here.
public enum PaperReviewLogic {
    private static let maxChars = 12_000

    public static let systemInstruction = """
    You are reviewing a real document a user uploaded to VISION, an honest writing-review tool. You will be given the document's real text. Do three things:
    1. Find real spelling/grammar issues. For each, quote the exact problematic excerpt from the text, give a corrected version, and a short explanation. If there are genuinely no issues, return an empty list — never invent one to fill it.
    2. Give a short list of general improvement suggestions (clarity, structure, flow).
    3. Write one honest paragraph assessing the writing itself — generic or formulaic phrasing, inconsistent voice, repetition, or other real signals you can actually observe in this text. You have no access to any database, search engine, or the internet, so you must NEVER claim to have checked this text against other sources or given it a similarity/plagiarism score — say only what you can genuinely observe in the text itself, and make clear this is your own reading, not a database match.

    Respond with ONLY a single fenced ```json code block containing an object of exactly this shape, nothing else:
    {"grammarIssues":[{"original":"the exact excerpt","suggestion":"the corrected text","explanation":"why"}],"improvementSuggestions":["...","..."],"originalityNote":"one honest paragraph"}
    """

    public static func boundedText(_ documentText: String) -> String {
        String(documentText.prefix(maxChars)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func parseReview(_ raw: String) -> PaperReview? {
        guard
            let data = raw.data(using: .utf8),
            let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return nil }

        var grammarIssues: [GrammarIssue] = []
        for g in (obj["grammarIssues"] as? [[String: Any]]) ?? [] {
            let original = (g["original"] as? String) ?? ""
            let suggestion = (g["suggestion"] as? String) ?? ""
            guard !original.isEmpty || !suggestion.isEmpty else { continue }
            grammarIssues.append(GrammarIssue(original: original, suggestion: suggestion, explanation: (g["explanation"] as? String) ?? ""))
        }

        let improvementSuggestions = ((obj["improvementSuggestions"] as? [String]) ?? []).filter { !$0.isEmpty }

        guard let originalityNote = obj["originalityNote"] as? String, !originalityNote.isEmpty else { return nil }

        return PaperReview(grammarIssues: grammarIssues, improvementSuggestions: improvementSuggestions, originalityNote: originalityNote)
    }
}
