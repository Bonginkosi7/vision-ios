import Foundation
import GRDB
import VisionCore

struct ExamTest: Codable, Identifiable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "examTest"
    var id: String
    var title: String
    var timeLimitMinutes: Int?
    var createdAt: Date
    var documentId: String?
}

struct ExamQuestionRecord: Codable, Identifiable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "examQuestion"
    var id: String
    var testId: String
    var ordinal: Int
    var type: String
    var prompt: String
    var optionsJSON: String?
    var correctAnswer: String
    var explanation: String?
    var topicId: String?

    var options: [String]? {
        guard let optionsJSON, let data = optionsJSON.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([String].self, from: data)
    }
}

struct ExamAttempt: Codable, Identifiable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "examAttempt"
    var id: String
    var testId: String
    var status: String
    var startedAt: Date
    var submittedAt: Date?
    var scorePercent: Double?
    var expiresAt: Date?
}

struct ExamAnswerRecord: Codable, Identifiable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "examAnswer"
    var id: String
    var attemptId: String
    var questionId: String
    var studentAnswer: String
    var isCorrect: Bool?
    var feedback: String?
    var markedAt: Date?
}

/// A question's full text plus its question count, for rendering a test's
/// list row — mirrors the `COUNT(q.id)` join ExamDbHelper.kt's listTests/
/// getTest do in SQL.
struct ExamTestSummary: Identifiable {
    let test: ExamTest
    let questionCount: Int
    var id: String { test.id }
}

struct ExamAnswerResult: Identifiable {
    let questionId: String
    let prompt: String
    let studentAnswer: String
    let isCorrect: Bool?
    let feedback: String?
    var id: String { questionId }
}

/// Real local storage for exams — GRDB port of ExamDbHelper.kt. Supports
/// all three real question types, including short_answer (marked by a
/// batched AI call via ShortAnswerMarker, see TakeExamView) — MCQ and
/// true/false are still marked instantly by real local string comparison
/// (ExamMarking), exactly like desktop/Android. `documentId` links an
/// AI-generated test back to its real source document — nil for a fully
/// user-authored one.
///
/// `markedAnswersForTopic` closes the trim this file's doc comment used
/// to describe: Performance (Phase 12) now exists and is the real
/// consumer of marked exam answers tagged to a topic.
final class ExamStore: ObservableObject {
    private let dbQueue: DatabaseQueue
    init(dbQueue: DatabaseQueue = AppDatabase.shared) { self.dbQueue = dbQueue }

    @discardableResult
    func createTest(title: String, timeLimitMinutes: Int?, questions: [RawExamQuestion], documentId: String? = nil) throws -> String {
        let testId = UUID().uuidString
        let now = Date()
        try dbQueue.write { db in
            try ExamTest(id: testId, title: title, timeLimitMinutes: timeLimitMinutes, createdAt: now, documentId: documentId).insert(db)
            for (index, q) in questions.enumerated() {
                let optionsJSON = q.options.flatMap { try? JSONEncoder().encode($0) }.flatMap { String(data: $0, encoding: .utf8) }
                try ExamQuestionRecord(
                    id: UUID().uuidString, testId: testId, ordinal: index, type: q.type, prompt: q.prompt,
                    optionsJSON: optionsJSON, correctAnswer: q.correctAnswer, explanation: q.explanation, topicId: q.topicId
                ).insert(db)
            }
        }
        return testId
    }

    func listTests() throws -> [ExamTestSummary] {
        try dbQueue.read { db in
            let tests = try ExamTest.order(Column("createdAt").desc).fetchAll(db)
            return try tests.map { test in
                let count = try ExamQuestionRecord.filter(Column("testId") == test.id).fetchCount(db)
                return ExamTestSummary(test: test, questionCount: count)
            }
        }
    }

    func deleteTest(_ testId: String) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM examAnswer WHERE attemptId IN (SELECT id FROM examAttempt WHERE testId = ?)", arguments: [testId])
            try ExamAttempt.filter(Column("testId") == testId).deleteAll(db)
            try ExamQuestionRecord.filter(Column("testId") == testId).deleteAll(db)
            _ = try ExamTest.deleteOne(db, key: testId)
        }
    }

    func getTest(_ testId: String) throws -> ExamTest? {
        try dbQueue.read { db in try ExamTest.fetchOne(db, key: testId) }
    }

    func questionsForTest(_ testId: String) throws -> [ExamQuestionRecord] {
        try dbQueue.read { db in
            try ExamQuestionRecord.filter(Column("testId") == testId).order(Column("ordinal").asc).fetchAll(db)
        }
    }

    func startAttempt(testId: String, timeLimitMinutes: Int?) throws -> ExamAttempt {
        let startedAt = Date()
        let expiresAt = timeLimitMinutes.map { startedAt.addingTimeInterval(TimeInterval($0) * 60) }
        let attempt = ExamAttempt(id: UUID().uuidString, testId: testId, status: "in_progress", startedAt: startedAt, submittedAt: nil, scorePercent: nil, expiresAt: expiresAt)
        try dbQueue.write { db in try attempt.insert(db) }
        return attempt
    }

    /// Marks every MCQ/true-false answer instantly and locally, always
    /// (real offline-capable marking, not simulated). Short-answer answers
    /// are inserted with isCorrect left nil — genuinely unmarked, not a
    /// fabricated placeholder — for the caller to mark next via
    /// ShortAnswerMarker. Returns the per-question results as they stand
    /// right after this call (short-answer ones carry isCorrect = nil).
    @discardableResult
    func submitAttempt(attemptId: String, testId: String, answers: [String: String]) throws -> [ExamAnswerResult] {
        let questions = try questionsForTest(testId)
        var results: [ExamAnswerResult] = []
        try dbQueue.write { db in
            for question in questions {
                let studentAnswer = answers[question.id] ?? ""
                if question.type == "short_answer" {
                    try ExamAnswerRecord(id: UUID().uuidString, attemptId: attemptId, questionId: question.id, studentAnswer: studentAnswer, isCorrect: nil, feedback: nil, markedAt: nil).insert(db)
                    results.append(ExamAnswerResult(questionId: question.id, prompt: question.prompt, studentAnswer: studentAnswer, isCorrect: nil, feedback: nil))
                    continue
                }

                let correct = ExamMarking.isCorrect(studentAnswer: studentAnswer, correctAnswer: question.correctAnswer)
                let feedback: String
                if correct {
                    feedback = "Correct."
                } else {
                    let correctText = ExamMarking.describeCorrectAnswer(type: question.type, correctAnswer: question.correctAnswer, options: question.options)
                    feedback = "Incorrect — correct answer: \(correctText).\(question.explanation.map { " \($0)" } ?? "")"
                }
                try ExamAnswerRecord(id: UUID().uuidString, attemptId: attemptId, questionId: question.id, studentAnswer: studentAnswer, isCorrect: correct, feedback: feedback, markedAt: Date()).insert(db)
                results.append(ExamAnswerResult(questionId: question.id, prompt: question.prompt, studentAnswer: studentAnswer, isCorrect: correct, feedback: feedback))
            }
            try db.execute(sql: "UPDATE examAttempt SET status = ?, submittedAt = ? WHERE id = ?", arguments: ["submitted", Date(), attemptId])
        }
        return results
    }

    /// Every short-answer answer in this attempt that's still genuinely unmarked.
    func pendingShortAnswers(attemptId: String) throws -> [(question: ExamQuestionRecord, answer: ExamAnswerResult)] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT a.questionId, a.studentAnswer, q.id AS qid, q.testId, q.ordinal, q.type, q.prompt, q.optionsJSON, q.correctAnswer, q.explanation
                FROM examAnswer a JOIN examQuestion q ON q.id = a.questionId
                WHERE a.attemptId = ? AND q.type = 'short_answer' AND a.isCorrect IS NULL
                """, arguments: [attemptId])
            return rows.map { row in
                let question = ExamQuestionRecord(
                    id: row["qid"], testId: row["testId"], ordinal: row["ordinal"], type: row["type"], prompt: row["prompt"],
                    optionsJSON: row["optionsJSON"], correctAnswer: row["correctAnswer"], explanation: row["explanation"], topicId: nil
                )
                let studentAnswer: String = row["studentAnswer"]
                return (question, ExamAnswerResult(questionId: question.id, prompt: question.prompt, studentAnswer: studentAnswer, isCorrect: nil, feedback: nil))
            }
        }
    }

    func markAnswer(attemptId: String, questionId: String, isCorrect: Bool, feedback: String) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE examAnswer SET isCorrect = ?, feedback = ?, markedAt = ? WHERE attemptId = ? AND questionId = ?",
                arguments: [isCorrect, feedback, Date(), attemptId, questionId]
            )
        }
    }

    func answersForAttempt(_ attemptId: String) throws -> [ExamAnswerResult] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT a.questionId, q.prompt, a.studentAnswer, a.isCorrect, a.feedback
                FROM examAnswer a JOIN examQuestion q ON q.id = a.questionId
                WHERE a.attemptId = ? ORDER BY q.ordinal ASC
                """, arguments: [attemptId])
            return rows.map { row in
                ExamAnswerResult(questionId: row["questionId"], prompt: row["prompt"], studentAnswer: row["studentAnswer"], isCorrect: row["isCorrect"], feedback: row["feedback"])
            }
        }
    }

    /// If every answer in the attempt now has a real mark, finalizes the
    /// attempt's score and returns it; otherwise leaves it pending and
    /// returns nil — never a partial/fabricated score.
    @discardableResult
    func finalizeIfComplete(_ attemptId: String) throws -> Double? {
        let answers = try answersForAttempt(attemptId)
        guard !answers.isEmpty, !answers.contains(where: { $0.isCorrect == nil }) else { return nil }
        let scorePercent = ExamMarking.scorePercent(correctCount: answers.filter { $0.isCorrect == true }.count, totalAnswers: answers.count)
        try dbQueue.write { db in
            try db.execute(sql: "UPDATE examAttempt SET status = ?, scorePercent = ? WHERE id = ?", arguments: ["marked", scorePercent, attemptId])
        }
        return scorePercent
    }

    /// Every real marked exam answer belonging to a question tagged to
    /// this topic, most recent first — feeds `MasteryEngine` via
    /// `PerformanceCalculator`. Direct port of ExamDbHelper.kt's
    /// markedAnswersForTopic.
    func markedAnswersForTopic(_ topicId: String) throws -> [MasteryEvent] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT a.isCorrect, a.markedAt
                FROM examAnswer a
                JOIN examQuestion q ON q.id = a.questionId
                WHERE q.topicId = ? AND a.isCorrect IS NOT NULL
                ORDER BY a.markedAt DESC
                """, arguments: [topicId])
            return rows.map { row in MasteryEvent(correct: row["isCorrect"], createdAt: row["markedAt"]) }
        }
    }
}
