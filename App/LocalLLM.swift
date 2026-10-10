import Foundation
import UIKit
import llama
import VisionCore

/// Real on-device inference through llama.cpp — the iOS counterpart of
/// Android's MediaPipe-backed LocalModelManager. Runs the downloaded
/// Qwen2.5 GGUF entirely on the phone: no network, nothing leaves the
/// device. An actor so the heavy decode loop never runs on the main
/// thread and two requests can't touch the model at once.
actor LocalLLM {
    static let shared = LocalLLM()

    private static let contextTokens: UInt32 = 2048
    private static let maxNewTokens = 512

    private var model: OpaquePointer?
    private var loadedPath: String?
    private var backendReady = false

    private init() {
        // Weights are ~650MB mapped into RAM — give them back when iOS
        // says memory is tight; the next question simply reloads them.
        Task { @MainActor in
            NotificationCenter.default.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main
            ) { _ in
                Task { await LocalLLM.shared.unload() }
            }
        }
    }

    func unload() {
        if let model { llama_model_free(model) }
        model = nil
        loadedPath = nil
    }

    enum LLMError: LocalizedError {
        case loadFailed, contextFailed, promptTooLong, decodeFailed
        var errorDescription: String? {
            switch self {
            case .loadFailed: return "The on-device model couldn't be loaded. Try removing and re-downloading it in Settings."
            case .contextFailed: return "Not enough memory to run the on-device model right now."
            case .promptTooLong: return "That message is too long for the on-device model."
            case .decodeFailed: return "The on-device model stopped unexpectedly."
            }
        }
    }

    private func ensureLoaded(path: String) throws -> OpaquePointer {
        if let model, loadedPath == path { return model }
        unload()
        if !backendReady {
            llama_backend_init()
            backendReady = true
        }
        var params = llama_model_default_params()
        params.n_gpu_layers = 99 // Metal; falls back to CPU below if it can't load
        var loaded = llama_model_load_from_file(path, params)
        if loaded == nil {
            params.n_gpu_layers = 0
            loaded = llama_model_load_from_file(path, params)
        }
        guard let loaded else { throw LLMError.loadFailed }
        model = loaded
        loadedPath = path
        return loaded
    }

    func generate(modelPath: String, systemInstruction: String, history: [ChatMessage], userMessage: String) throws -> String {
        let model = try ensureLoaded(path: modelPath)
        guard let vocab = llama_model_get_vocab(model) else { throw LLMError.loadFailed }

        // Drop the oldest turns until system + history + question fit the
        // context window with room left to answer.
        var turns = history
        var tokens: [llama_token] = []
        while true {
            let prompt = Self.formatPrompt(model: model, system: systemInstruction, history: turns, user: userMessage)
            tokens = Self.tokenize(vocab: vocab, text: prompt)
            if tokens.count + Self.maxNewTokens <= Int(Self.contextTokens) { break }
            if turns.isEmpty { throw LLMError.promptTooLong }
            turns.removeFirst()
        }

        var ctxParams = llama_context_default_params()
        ctxParams.n_ctx = Self.contextTokens
        ctxParams.n_batch = Self.contextTokens
        ctxParams.n_threads = Int32(max(2, min(4, ProcessInfo.processInfo.activeProcessorCount - 2)))
        ctxParams.n_threads_batch = ctxParams.n_threads
        guard let ctx = llama_init_from_model(model, ctxParams) else { throw LLMError.contextFailed }
        defer { llama_free(ctx) }

        let chain = llama_sampler_chain_init(llama_sampler_chain_default_params())
        llama_sampler_chain_add(chain, llama_sampler_init_penalties(llama_vocab_n_tokens(vocab), 64, 1.1, 0, 0))
        llama_sampler_chain_add(chain, llama_sampler_init_top_p(0.9, 1))
        llama_sampler_chain_add(chain, llama_sampler_init_temp(0.6))
        llama_sampler_chain_add(chain, llama_sampler_init_dist(UInt32.random(in: 0...UInt32.max)))
        defer { llama_sampler_free(chain) }

        var output: [UInt8] = []
        var pending = tokens
        var generated = 0
        while generated < Self.maxNewTokens, !Task.isCancelled {
            let status: Int32 = pending.withUnsafeMutableBufferPointer { buffer in
                llama_decode(ctx, llama_batch_get_one(buffer.baseAddress, Int32(buffer.count)))
            }
            if status != 0 { if output.isEmpty { throw LLMError.decodeFailed } else { break } }

            let next = llama_sampler_sample(chain, ctx, -1)
            if llama_vocab_is_eog(vocab, next) { break }
            output.append(contentsOf: Self.piece(vocab: vocab, token: next))
            pending = [next]
            generated += 1
        }
        return String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - helpers

    private static func formatPrompt(model: OpaquePointer, system: String, history: [ChatMessage], user: String) -> String {
        let messages: [(String, String)] =
            [("system", system)] + history.map { ($0.role == "assistant" ? "assistant" : "user", $0.content) } + [("user", user)]
        let cRoles = messages.map { strdup($0.0) }
        let cContents = messages.map { strdup($0.1) }
        defer { cRoles.forEach { free($0) }; cContents.forEach { free($0) } }
        var chat = (0..<messages.count).map { llama_chat_message(role: UnsafePointer(cRoles[$0]), content: UnsafePointer(cContents[$0])) }

        // The template embedded in the model file itself (Qwen's ChatML).
        let template = llama_model_chat_template(model, nil)
        var capacity = messages.reduce(0) { $0 + $1.1.utf8.count + $1.0.utf8.count } * 2 + 256
        var buffer = [CChar](repeating: 0, count: capacity)
        var written = llama_chat_apply_template(template, &chat, chat.count, true, &buffer, Int32(capacity))
        if Int(written) > capacity {
            capacity = Int(written) + 1
            buffer = [CChar](repeating: 0, count: capacity)
            written = llama_chat_apply_template(template, &chat, chat.count, true, &buffer, Int32(capacity))
        }
        guard written > 0 else {
            // No usable template — plain ChatML, which Qwen2.5 is trained on.
            return messages.map { "<|im_start|>\($0.0)\n\($0.1)<|im_end|>\n" }.joined() + "<|im_start|>assistant\n"
        }
        return String(decoding: buffer.prefix(Int(written)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    private static func tokenize(vocab: OpaquePointer, text: String) -> [llama_token] {
        let utf8Count = text.utf8.count
        var tokens = [llama_token](repeating: 0, count: utf8Count + 8)
        var count = llama_tokenize(vocab, text, Int32(utf8Count), &tokens, Int32(tokens.count), true, true)
        if count < 0 {
            tokens = [llama_token](repeating: 0, count: Int(-count))
            count = llama_tokenize(vocab, text, Int32(utf8Count), &tokens, Int32(tokens.count), true, true)
        }
        return Array(tokens.prefix(max(0, Int(count))))
    }

    private static func piece(vocab: OpaquePointer, token: llama_token) -> [UInt8] {
        var buffer = [CChar](repeating: 0, count: 64)
        var n = llama_token_to_piece(vocab, token, &buffer, Int32(buffer.count), 0, false)
        if n < 0 {
            buffer = [CChar](repeating: 0, count: Int(-n))
            n = llama_token_to_piece(vocab, token, &buffer, Int32(buffer.count), 0, false)
        }
        return buffer.prefix(max(0, Int(n))).map { UInt8(bitPattern: $0) }
    }
}

/// Plugs the on-device model into the same provider list the cloud AIs use,
/// after them — so a configured cloud key still wins, and this answers when
/// none is configured or the network is down.
struct LocalModelProvider: CloudAIProvider {
    let name = "On-device"

    func isAvailable() -> Bool { LocalModelFile.isDownloaded }

    func generate(systemInstruction: String, userMessage: String, history: [ChatMessage]) async -> AiCallResult {
        do {
            let text = try await LocalLLM.shared.generate(
                modelPath: LocalModelFile.url.path, systemInstruction: systemInstruction, history: history, userMessage: userMessage
            )
            return AiCallResult(ok: true, text: text, providerName: name, error: nil)
        } catch {
            return AiCallResult(ok: false, text: nil, providerName: name, error: error.localizedDescription)
        }
    }
}
