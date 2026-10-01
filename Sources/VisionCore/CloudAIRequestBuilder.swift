import Foundation

/// One real prior turn of a conversation — role is "user" or "assistant",
/// oldest first. Direct port of ChatMessage (CloudAiProvider.kt).
public struct ChatMessage {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

/// Pure request-building and response-parsing logic for the two real cloud
/// AI providers — deliberately separated from the actual URLSession
/// networking (see App/CloudAIProvider.swift) so this stays testable
/// without Xcode or a network call, the same real-verification discipline
/// AddressResolver/TabIndexing already established. Same endpoints,
/// headers, and default models as CloudAiProvider.kt (itself matching
/// desktop's src/main/ai/AIProvider.ts).
public enum CloudAIRequestBuilder {
    public struct Request {
        public let url: URL
        public let headers: [String: String]
        public let body: Data
    }

    public static func anthropicRequest(
        apiKey: String,
        systemInstruction: String,
        userMessage: String,
        history: [ChatMessage] = []
    ) throws -> Request {
        var messages: [[String: String]] = history.map { ["role": $0.role, "content": $0.content] }
        messages.append(["role": "user", "content": userMessage])

        let bodyDict: [String: Any] = [
            "model": "claude-sonnet-5",
            "max_tokens": 1024,
            "system": systemInstruction,
            "messages": messages,
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: bodyDict)

        return Request(
            url: URL(string: "https://api.anthropic.com/v1/messages")!,
            headers: [
                "x-api-key": apiKey,
                "anthropic-version": "2023-06-01",
                "content-type": "application/json",
            ],
            body: bodyData
        )
    }

    public static func openAIRequest(
        apiKey: String,
        systemInstruction: String,
        userMessage: String,
        history: [ChatMessage] = []
    ) throws -> Request {
        var messages: [[String: String]] = [["role": "system", "content": systemInstruction]]
        messages.append(contentsOf: history.map { ["role": $0.role, "content": $0.content] })
        messages.append(["role": "user", "content": userMessage])

        let bodyDict: [String: Any] = [
            "model": "gpt-4o",
            "messages": messages,
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: bodyDict)

        return Request(
            url: URL(string: "https://api.openai.com/v1/chat/completions")!,
            headers: [
                "authorization": "Bearer \(apiKey)",
                "content-type": "application/json",
            ],
            body: bodyData
        )
    }

    /// Extracts the real reply text from an Anthropic Messages API
    /// response: `content` is an array of typed blocks; the first `"text"`
    /// block is the one that matters, same as CloudAiProvider.kt's loop.
    public static func parseAnthropicResponseText(_ data: Data) -> String? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = json["content"] as? [[String: Any]]
        else { return nil }

        for block in content where block["type"] as? String == "text" {
            if let text = block["text"] as? String { return text }
        }
        return nil
    }

    /// Extracts the real reply text from an OpenAI Chat Completions API
    /// response: `choices[0].message.content`.
    public static func parseOpenAIResponseText(_ data: Data) -> String? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let text = message["content"] as? String
        else { return nil }
        return text
    }
}
