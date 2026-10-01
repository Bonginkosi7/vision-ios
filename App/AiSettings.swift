import Foundation

/// Real, encrypted storage for the user's own cloud AI API keys — direct
/// port of AiSettings.kt, backed by KeychainStore instead of
/// EncryptedSharedPreferences. Same reasoning for why this exists at all:
/// desktop's `ANTHROPIC_API_KEY`/`OPENAI_API_KEY` environment variables are
/// set by whoever launches that dev instance, which has no meaning for a
/// distributed App Store binary — so unlike desktop (no in-app key entry
/// UI), this app needs a real Settings screen for the user to paste in
/// their own key.
enum AiSettings {
    private static let anthropicKeyName = "anthropic_api_key"
    private static let openAiKeyName = "openai_api_key"

    static func getAnthropicKey() -> String? {
        KeychainStore.get(forKey: anthropicKeyName).flatMap { $0.isEmpty ? nil : $0 }
    }

    static func setAnthropicKey(_ key: String) {
        KeychainStore.set(key.trimmingCharacters(in: .whitespacesAndNewlines), forKey: anthropicKeyName)
    }

    static func clearAnthropicKey() {
        KeychainStore.delete(forKey: anthropicKeyName)
    }

    static func getOpenAiKey() -> String? {
        KeychainStore.get(forKey: openAiKeyName).flatMap { $0.isEmpty ? nil : $0 }
    }

    static func setOpenAiKey(_ key: String) {
        KeychainStore.set(key.trimmingCharacters(in: .whitespacesAndNewlines), forKey: openAiKeyName)
    }

    static func clearOpenAiKey() {
        KeychainStore.delete(forKey: openAiKeyName)
    }
}
