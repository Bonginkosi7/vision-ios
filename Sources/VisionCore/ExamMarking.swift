import Foundation

/// Pure marking logic, direct port of ExamMarking.kt (itself a port of
/// desktop's marking.ts) — real local comparison, no AI involved. Covers
/// MCQ/true-false only; short-answer questions are marked by a real
/// batched AI call instead (ShortAnswerMarkingLogic.swift), same split as
/// desktop and Android.
public enum ExamMarking {
    public static func isCorrect(studentAnswer: String, correctAnswer: String) -> Bool {
        studentAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
    }

    /// For MCQ, correctAnswer is stored as a real option index (matching
    /// the exam UI's own picker value) — this resolves it back to the
    /// actual answer text for feedback.
    public static func describeCorrectAnswer(type: String, correctAnswer: String, options: [String]?) -> String {
        if type == "mcq", let index = Int(correctAnswer), let options, options.indices.contains(index) {
            return options[index]
        }
        return correctAnswer
    }

    public static func scorePercent(correctCount: Int, totalAnswers: Int) -> Double {
        totalAnswers > 0 ? (Double(correctCount) / Double(totalAnswers)) * 100 : 0.0
    }
}
