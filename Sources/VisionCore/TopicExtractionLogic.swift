import Foundation

public struct RawSubtopic: Equatable {
    public let name: String
    public let summary: String

    public init(name: String, summary: String) {
        self.name = name
        self.summary = summary
    }
}

public struct RawTopic: Equatable {
    public let name: String
    public let summary: String
    public let subtopics: [RawSubtopic]

    public init(name: String, summary: String, subtopics: [RawSubtopic]) {
        self.name = name
        self.summary = summary
        self.subtopics = subtopics
    }
}

/// Real AI-backed topic extraction grounded in a processed document's
/// real extracted text — direct port of TopicExtractionLogic.kt. Pure
/// prompt-building and response-parsing only; the actual AI call lives
/// in App/StructuredAI.swift + App/TopicExtractor.swift, the same real/
/// pure split CloudAIRequestBuilder/CloudAIProvider already established.
public enum TopicExtractionLogic {
    private static let maxChars = 12_000

    public static let systemInstruction = """
    You are analyzing a real uploaded study document for VISION, an honest AI study tool. You will be given the document's real text. Identify the real subjects/topics and subtopics this document actually covers, based only on the given text — never invent a topic that isn't reflected in it.

    Respond with ONLY a single fenced ```json code block containing an object of exactly this shape, nothing else:
    {"topics":[{"name":"...","summary":"one honest sentence","subtopics":[{"name":"...","summary":"one honest sentence"}]}]}

    Use however many top-level topics honestly reflect the material (typically 3-12). Subtopics are optional — an empty array is fine; only include ones genuinely distinguishable in the given text.
    """

    public static func boundedText(_ documentText: String) -> String {
        String(documentText.prefix(maxChars)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func parseTopics(_ raw: String) -> [RawTopic]? {
        guard
            let data = raw.data(using: .utf8),
            let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
            let array = obj["topics"] as? [[String: Any]]
        else { return nil }

        var topics: [RawTopic] = []
        for t in array {
            guard let rawName = t["name"] as? String else { continue }
            let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let summary = (t["summary"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            var subtopics: [RawSubtopic] = []
            if let subArray = t["subtopics"] as? [[String: Any]] {
                for s in subArray {
                    guard
                        let rawSubName = s["name"] as? String
                    else { continue }
                    let subName = rawSubName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !subName.isEmpty else { continue }
                    let subSummary = (s["summary"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    subtopics.append(RawSubtopic(name: subName, summary: subSummary))
                }
            }
            topics.append(RawTopic(name: name, summary: summary, subtopics: subtopics))
        }
        return topics.isEmpty ? nil : topics
    }
}
