import Foundation

public struct PendingShortAnswer: Equatable {
    public let questionId: String
    public let prompt: String
    public let modelAnswer: String
    public let studentAnswer: String
    public init(questionId: String, prompt: String, modelAnswer: String, studentAnswer: String) {
        self.questionId = questionId; self.prompt = prompt
        self.modelAnswer = modelAnswer; self.studentAnswer = studentAnswer
    }
}

public struct ShortAnswerMarking: Equatable {
    public let questionId: String
    public let isCorrect: Bool
    public let feedback: String
    public init(questionId: String, isCorrect: Bool, feedback: String) {
        self.questionId = questionId; self.isCorrect = isCorrect; self.feedback = feedback
    }
}

/// Pure prompt-building/parsing half of ShortAnswerMarkingLogic.kt's real
/// batched AI marking — one call covers every still-unmarked short-answer
/// question in an attempt together (atomic: the whole batch succeeds or
/// stays pending), far cheaper than one call per question. The actual
/// network call lives in App/ShortAnswerMarker.swift, same real/pure split
/// as TopicExtractionLogic/TopicExtractor and FlashcardGenerationLogic/
/// FlashcardGenerator.
public enum ShortAnswerMarkingLogic {
    public static func systemInstruction() -> String {
        """
        You are marking a student's short-answer responses for VISION, an honest AI study tool. For each numbered question you'll see the question prompt, a real model answer, and the student's actual response. Decide if the student's answer is substantively correct — don't require exact wording, award credit for a correct answer expressed differently — and give brief, specific feedback.

        Respond with ONLY a single fenced ```json code block containing an object of exactly this shape, nothing else:
        {"markings":[{"questionIndex":0,"isCorrect":true,"feedback":"..."}]}
        """
    }

    public static func prompt(for pending: [PendingShortAnswer]) -> String {
        pending.enumerated().map { index, answer in
            let studentAnswer = answer.studentAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
            return "(\(index)) Question: \(answer.prompt)\nModel answer: \(answer.modelAnswer)\nStudent's answer: \(studentAnswer.isEmpty ? "(no answer given)" : studentAnswer)"
        }.joined(separator: "\n---\n")
    }

    public static func parseMarkings(_ raw: String, pending: [PendingShortAnswer]) -> [ShortAnswerMarking]? {
        guard
            let data = raw.data(using: .utf8),
            let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
            let array = obj["markings"] as? [[String: Any]]
        else { return nil }

        var result: [ShortAnswerMarking] = []
        for m in array {
            guard let index = m["questionIndex"] as? Int, pending.indices.contains(index) else { continue }
            guard let isCorrect = m["isCorrect"] as? Bool else { continue }
            let feedback = (m["feedback"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedFeedback = (feedback?.isEmpty ?? true) ? (isCorrect ? "Correct." : "Not quite right.") : feedback!
            result.append(ShortAnswerMarking(questionId: pending[index].questionId, isCorrect: isCorrect, feedback: resolvedFeedback))
        }
        return result.isEmpty ? nil : result
    }
}
