import Foundation
import VisionCore

/// Real cloud AI call result — direct port of AiCallResult (CloudAiProvider.kt).
struct AiCallResult {
    let ok: Bool
    let text: String?
    let providerName: String
    let error: String?
}

/// Real cloud AI call — a provider this app can actually reach right now
/// with the user's own key (checked via `isAvailable()` before
/// `generate()` is ever called). Direct port of CloudAiProvider.kt's
/// interface; request-building and response-parsing are pure logic in
/// VisionCore.CloudAIRequestBuilder (real-verified without Xcode — see
/// README), this file is only the real `URLSession` networking glue.
protocol CloudAIProvider {
    var name: String { get }
    func isAvailable() -> Bool
    func generate(systemInstruction: String, userMessage: String, history: [ChatMessage]) async -> AiCallResult
}

private let requestTimeout: TimeInterval = 15

/// Calls the real Anthropic Messages API — same endpoint, headers, and
/// default model as CloudAiProvider.kt's AnthropicProvider (itself
/// matching desktop's own AIProvider.ts), reading the key from AiSettings'
/// real Keychain store instead of an environment variable.
struct AnthropicProvider: CloudAIProvider {
    let name = "Claude"

    func isAvailable() -> Bool {
        AiSettings.getAnthropicKey() != nil
    }

    func generate(systemInstruction: String, userMessage: String, history: [ChatMessage] = []) async -> AiCallResult {
        guard let apiKey = AiSettings.getAnthropicKey() else {
            return AiCallResult(ok: false, text: nil, providerName: name, error: "No Anthropic API key configured.")
        }
        do {
            let request = try CloudAIRequestBuilder.anthropicRequest(
                apiKey: apiKey, systemInstruction: systemInstruction, userMessage: userMessage, history: history
            )
            let (data, response) = try await send(request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                return AiCallResult(ok: false, text: nil, providerName: name, error: "API error: \(statusCode) \(String(data: data, encoding: .utf8) ?? "")")
            }
            let text = CloudAIRequestBuilder.parseAnthropicResponseText(data) ?? ""
            return AiCallResult(ok: true, text: text, providerName: name, error: nil)
        } catch {
            return AiCallResult(ok: false, text: nil, providerName: name, error: "Anthropic request failed: \(error.localizedDescription)")
        }
    }
}

/// Calls the real OpenAI Chat Completions API — same endpoint, headers,
/// and default model as CloudAiProvider.kt's OpenAiProvider.
struct OpenAIProvider: CloudAIProvider {
    let name = "ChatGPT"

    func isAvailable() -> Bool {
        AiSettings.getOpenAiKey() != nil
    }

    func generate(systemInstruction: String, userMessage: String, history: [ChatMessage] = []) async -> AiCallResult {
        guard let apiKey = AiSettings.getOpenAiKey() else {
            return AiCallResult(ok: false, text: nil, providerName: name, error: "No OpenAI API key configured.")
        }
        do {
            let request = try CloudAIRequestBuilder.openAIRequest(
                apiKey: apiKey, systemInstruction: systemInstruction, userMessage: userMessage, history: history
            )
            let (data, response) = try await send(request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                return AiCallResult(ok: false, text: nil, providerName: name, error: "API error: \(statusCode) \(String(data: data, encoding: .utf8) ?? "")")
            }
            let text = CloudAIRequestBuilder.parseOpenAIResponseText(data) ?? ""
            return AiCallResult(ok: true, text: text, providerName: name, error: nil)
        } catch {
            return AiCallResult(ok: false, text: nil, providerName: name, error: "OpenAI request failed: \(error.localizedDescription)")
        }
    }
}

/// Shared real network call for both providers — `URLSession`'s own
/// async/await API, the natural Swift equivalent of CloudAiProvider.kt's
/// shared `postJson` using `HttpURLConnection` (no third-party networking
/// library needed here either, matching that same minimal-dependency
/// choice).
private func send(_ request: CloudAIRequestBuilder.Request) async throws -> (Data, URLResponse) {
    var urlRequest = URLRequest(url: request.url, timeoutInterval: requestTimeout)
    urlRequest.httpMethod = "POST"
    urlRequest.httpBody = request.body
    for (key, value) in request.headers {
        urlRequest.setValue(value, forHTTPHeaderField: key)
    }
    return try await URLSession.shared.data(for: urlRequest)
}
