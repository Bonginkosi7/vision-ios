import Foundation
import VisionCore

/// Build-time settings for VISION's own AI service (the vision-ai-proxy
/// server), injected the same way as the analytics values. Empty until the
/// server is deployed, in which case this provider reports itself
/// unavailable and everything behaves as before. The OpenAI key itself is
/// never in the app — only the server holds it.
enum VisionAIConfig {
    static var baseURL: String {
        Bundle.main.object(forInfoDictionaryKey: "VisionAIProxyURL") as? String ?? ""
    }
    static var appKey: String {
        Bundle.main.object(forInfoDictionaryKey: "VisionAIProxyKey") as? String ?? ""
    }
    static func isConfigured() -> Bool { URL(string: baseURL)?.scheme == "https" && !appKey.isEmpty }

    /// Random per-install id the server uses only to apply fair-use limits.
    static var installId: String {
        let key = "vision_ai_install_id"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let created = UUID().uuidString
        UserDefaults.standard.set(created, forKey: key)
        return created
    }
}

/// VISION's own cloud AI — the app's default answer source for anyone who
/// hasn't pasted their own key. Tried after a user's own key (which costs
/// the owner nothing) and before the offline model.
struct VisionCloudProvider: CloudAIProvider {
    let name = "VISION AI"

    func isAvailable() -> Bool { VisionAIConfig.isConfigured() }

    func generate(systemInstruction: String, userMessage: String, history: [ChatMessage]) async -> AiCallResult {
        guard let url = URL(string: VisionAIConfig.baseURL)?.appendingPathComponent("v1/chat") else {
            return AiCallResult(ok: false, text: nil, providerName: name, error: "VISION AI isn't configured.")
        }
        let messages = history.map { ["role": $0.role == "assistant" ? "assistant" : "user", "content": $0.content] }
            + [["role": "user", "content": userMessage]]
        guard let body = try? JSONSerialization.data(withJSONObject: ["system": systemInstruction, "messages": messages]) else {
            return AiCallResult(ok: false, text: nil, providerName: name, error: "Couldn't build the request.")
        }
        var request = URLRequest(url: url, timeoutInterval: 50)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(VisionAIConfig.appKey, forHTTPHeaderField: "x-vision-app-key")
        request.setValue(VisionAIConfig.installId, forHTTPHeaderField: "x-vision-install")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            guard status == 200, let text = json?["text"] as? String else {
                let message = (json?["error"] as? String) ?? "VISION AI is unavailable right now."
                return AiCallResult(ok: false, text: nil, providerName: name, error: message)
            }
            return AiCallResult(ok: true, text: text, providerName: name, error: nil)
        } catch {
            // Offline or unreachable — the caller moves on to the next provider
            // (the on-device model, for chat).
            return AiCallResult(ok: false, text: nil, providerName: name, error: "Couldn't reach VISION AI: \(error.localizedDescription)")
        }
    }
}
