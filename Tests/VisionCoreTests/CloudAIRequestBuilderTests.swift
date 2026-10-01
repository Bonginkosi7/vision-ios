import XCTest
@testable import VisionCore

/// Real request/response shape verification for the two cloud AI
/// providers — no network call, same real-verification-without-Xcode
/// discipline as AddressResolverTests/TabIndexingTests.
final class CloudAIRequestBuilderTests: XCTestCase {

    private func jsonBody(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func test_anthropicRequest_hasTheRealEndpointAndHeaders() throws {
        let request = try CloudAIRequestBuilder.anthropicRequest(
            apiKey: "test-key", systemInstruction: "be helpful", userMessage: "hello"
        )
        XCTAssertEqual(request.url.absoluteString, "https://api.anthropic.com/v1/messages")
        XCTAssertEqual(request.headers["x-api-key"], "test-key")
        XCTAssertEqual(request.headers["anthropic-version"], "2023-06-01")
    }

    func test_anthropicRequest_bodyHasTheRealDefaultModelAndSystemInstruction() throws {
        let request = try CloudAIRequestBuilder.anthropicRequest(
            apiKey: "test-key", systemInstruction: "be helpful", userMessage: "hello"
        )
        let body = try jsonBody(request.body)
        XCTAssertEqual(body["model"] as? String, "claude-sonnet-5")
        XCTAssertEqual(body["max_tokens"] as? Int, 1024)
        XCTAssertEqual(body["system"] as? String, "be helpful")
        let messages = try XCTUnwrap(body["messages"] as? [[String: String]])
        XCTAssertEqual(messages.last?["role"], "user")
        XCTAssertEqual(messages.last?["content"], "hello")
    }

    func test_anthropicRequest_includesRealPriorHistoryInOrder() throws {
        let history = [ChatMessage(role: "user", content: "first"), ChatMessage(role: "assistant", content: "second")]
        let request = try CloudAIRequestBuilder.anthropicRequest(
            apiKey: "test-key", systemInstruction: "", userMessage: "third", history: history
        )
        let body = try jsonBody(request.body)
        let messages = try XCTUnwrap(body["messages"] as? [[String: String]])
        XCTAssertEqual(messages.map { $0["content"] }, ["first", "second", "third"])
    }

    func test_openAIRequest_hasTheRealEndpointAndAuthHeader() throws {
        let request = try CloudAIRequestBuilder.openAIRequest(
            apiKey: "test-key", systemInstruction: "be helpful", userMessage: "hello"
        )
        XCTAssertEqual(request.url.absoluteString, "https://api.openai.com/v1/chat/completions")
        XCTAssertEqual(request.headers["authorization"], "Bearer test-key")
    }

    func test_openAIRequest_bodyHasTheRealDefaultModelAndSystemMessageFirst() throws {
        let request = try CloudAIRequestBuilder.openAIRequest(
            apiKey: "test-key", systemInstruction: "be helpful", userMessage: "hello"
        )
        let body = try jsonBody(request.body)
        XCTAssertEqual(body["model"] as? String, "gpt-4o")
        let messages = try XCTUnwrap(body["messages"] as? [[String: String]])
        XCTAssertEqual(messages.first?["role"], "system")
        XCTAssertEqual(messages.first?["content"], "be helpful")
        XCTAssertEqual(messages.last?["role"], "user")
        XCTAssertEqual(messages.last?["content"], "hello")
    }

    func test_parseAnthropicResponseText_extractsTheFirstTextBlock() {
        let json = """
        {"content":[{"type":"text","text":"real reply"}],"id":"msg_123","model":"claude-sonnet-5"}
        """
        let text = CloudAIRequestBuilder.parseAnthropicResponseText(Data(json.utf8))
        XCTAssertEqual(text, "real reply")
    }

    func test_parseAnthropicResponseText_returnsNilForAnUnexpectedShape() {
        let text = CloudAIRequestBuilder.parseAnthropicResponseText(Data("{}".utf8))
        XCTAssertNil(text)
    }

    func test_parseOpenAIResponseText_extractsTheMessageContent() {
        let json = """
        {"choices":[{"message":{"role":"assistant","content":"real reply"}}]}
        """
        let text = CloudAIRequestBuilder.parseOpenAIResponseText(Data(json.utf8))
        XCTAssertEqual(text, "real reply")
    }

    func test_parseOpenAIResponseText_returnsNilForAnUnexpectedShape() {
        let text = CloudAIRequestBuilder.parseOpenAIResponseText(Data("{}".utf8))
        XCTAssertNil(text)
    }
}
