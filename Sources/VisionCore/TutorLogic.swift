import Foundation

public struct TutorAnswer: Equatable {
    public let text: String
    public let groundedInDocument: Bool
    public let providerName: String?
    public init(text: String, groundedInDocument: Bool, providerName: String?) {
        self.text = text; self.groundedInDocument = groundedInDocument; self.providerName = providerName
    }
}

/// Pure prompt-building half of real AI-backed tutoring — direct port of
/// TutorLogic.kt (itself the honest equivalent of desktop's
/// answerTutorQuestion, minus desktop's lesson-moment grounding and
/// numbered-chunk retrieval, which this app has no chunking layer to
/// support yet — see My Materials/Exams). The actual network call loop
/// lives in App/TutorAI.swift, same real/pure split established for every
/// other AI feature in this app. Unlike StructuredAI's callers, this
/// answer is free-text, not structured JSON — there's nothing to parse,
/// so no StructuredAI/retry plumbing applies here.
public enum TutorLogic {
    public static let maxDocumentChars = 8_000
    public static let maxHistoryMessages = 20

    private static let generalInstruction = """
    You are VISION's AI Tutor, an honest study assistant. Answer the student's question helpfully and clearly. No uploaded document is selected for this question, so answer from your general knowledge — do not claim to be drawing on any uploaded material.
    """

    public static let unconfiguredAnswer = TutorAnswer(
        text: "I don't have a cloud AI provider configured right now — add an OpenAI or Anthropic API key in Settings to chat with me.",
        groundedInDocument: false,
        providerName: nil
    )

    /// Honest about a real limitation, not a false claim of relevance-
    /// matching: unlike desktop's real keyword-scored chunk retrieval,
    /// this just includes the document's own whole bounded text as
    /// context, and says exactly that rather than claiming excerpts were
    /// "retrieved because they matched the question".
    public static func systemInstruction(documentText: String?) -> (instruction: String, groundedInDocument: Bool) {
        guard let documentText, !documentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return (generalInstruction, false)
        }
        let bounded = String(documentText.prefix(maxDocumentChars)).trimmingCharacters(in: .whitespacesAndNewlines)
        let instruction = """
        You are VISION's AI Tutor, an honest study assistant helping a student with their own uploaded material. Below is the real text of that material (it may be truncated if long):

        \(bounded)

        Answer using this material when it's relevant — if you do, make clear your answer is based on the student's uploaded material. If the material doesn't actually cover what's being asked, say so honestly and answer from general knowledge instead, rather than forcing an answer out of unrelated text.
        """
        return (instruction, true)
    }

    public static func trimmedHistory(_ history: [ChatMessage]) -> [ChatMessage] {
        Array(history.suffix(maxHistoryMessages))
    }
}
