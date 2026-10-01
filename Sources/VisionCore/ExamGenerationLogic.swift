import Foundation

public struct ExamGenerationCounts: Equatable {
    public let mcq: Int
    public let trueFalse: Int
    public let shortAnswer: Int
    public init(mcq: Int, trueFalse: Int, shortAnswer: Int) {
        self.mcq = mcq; self.trueFalse = trueFalse; self.shortAnswer = shortAnswer
    }
    public var total: Int { mcq + trueFalse + shortAnswer }
}

public struct RawExamQuestion: Equatable {
    public let type: String
    public let prompt: String
    public let options: [String]?
    public let correctAnswer: String
    public let explanation: String?
    public let topicId: String?
    public init(type: String, prompt: String, options: [String]?, correctAnswer: String, explanation: String?, topicId: String? = nil) {
        self.type = type; self.prompt = prompt; self.options = options
        self.correctAnswer = correctAnswer; self.explanation = explanation; self.topicId = topicId
    }
}

/// Real AI-backed mock-test generation grounded in a processed document's
/// real extracted text — direct port of ExamGenerationLogic.kt (itself the
/// honest equivalent of desktop's generateMockTest, minus desktop's
/// numbered-chunk/topic-scoping machinery, which this app has no chunking
/// layer to support yet). One batched call generates the whole question
/// set together, same as desktop/Android, so the model can avoid duplicate
/// questions across types and cost/latency stays bounded to one request.
/// Topic tagging reuses TopicTagging.swift exactly as FlashcardGenerationLogic does.
public enum ExamGenerationLogic {
    private static let maxChars = 12_000

    public static func systemInstruction(counts: ExamGenerationCounts, topics: [TopicRef]) -> String {
        let base = """
        You are generating a real mock test for VISION from a student's own uploaded study material. You will be given the real text of that material. Generate exactly \(counts.mcq) multiple-choice questions, \(counts.trueFalse) true/false questions, and \(counts.shortAnswer) short-answer questions — every question grounded in the given text, never inventing facts not present in it.

        Respond with ONLY a single fenced ```json code block containing an object of exactly this shape, nothing else:
        {"questions":[
          {"type":"mcq","prompt":"...","options":["option A","option B","option C","option D"],"correctOptionIndex":0,"explanation":"why this is correct"},
          {"type":"true_false","prompt":"a statement that is true or false","correctAnswer":"true","explanation":"why"},
          {"type":"short_answer","prompt":"...","modelAnswer":"a real model answer to compare a student's response against","explanation":"why"}
        ]}

        "options" must have at least 2 entries for mcq. "correctAnswer" for true_false must be exactly "true" or "false".
        """
        return base + TopicTagging.promptFragment(topics)
    }

    public static func boundedText(_ documentText: String) -> String {
        String(documentText.prefix(maxChars)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func parseQuestions(_ raw: String, topics: [TopicRef]) -> [RawExamQuestion]? {
        guard
            let data = raw.data(using: .utf8),
            let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
            let array = obj["questions"] as? [[String: Any]]
        else { return nil }

        var questions: [RawExamQuestion] = []
        for q in array {
            if let question = resolveQuestion(q, topics: topics) {
                questions.append(question)
            }
        }
        return questions.isEmpty ? nil : questions
    }

    private static func resolveQuestion(_ q: [String: Any], topics: [TopicRef]) -> RawExamQuestion? {
        guard let type = q["type"] as? String else { return nil }
        let prompt = (q["prompt"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !prompt.isEmpty else { return nil }
        let explanation = (q["explanation"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let topicId = TopicTagging.resolveTopicId(q["topicName"] as? String, topics)

        switch type {
        case "mcq":
            guard let optionsArray = q["options"] as? [String] else { return nil }
            let options = optionsArray.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            guard let correctIndex = q["correctOptionIndex"] as? Int, options.count >= 2, options.indices.contains(correctIndex) else { return nil }
            return RawExamQuestion(type: "mcq", prompt: prompt, options: options, correctAnswer: String(correctIndex), explanation: explanation?.isEmpty == true ? nil : explanation, topicId: topicId)
        case "true_false":
            let answer = (q["correctAnswer"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            guard answer == "true" || answer == "false" else { return nil }
            return RawExamQuestion(type: "true_false", prompt: prompt, options: nil, correctAnswer: answer, explanation: explanation?.isEmpty == true ? nil : explanation, topicId: topicId)
        case "short_answer":
            guard let modelAnswer = (q["modelAnswer"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !modelAnswer.isEmpty else { return nil }
            return RawExamQuestion(type: "short_answer", prompt: prompt, options: nil, correctAnswer: modelAnswer, explanation: explanation?.isEmpty == true ? nil : explanation, topicId: topicId)
        default:
            return nil
        }
    }
}
