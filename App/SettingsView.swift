import SwiftUI
import WebKit

/// Real settings — port of the slice of SettingsActivity.kt this phase's
/// scope actually needs: theme, search engine, offline storage limit,
/// the two cloud AI key rows (save/clear/status, same real UX pattern as
/// SettingsActivity.kt's setUpAiKeyRow), and real Clear Browsing Data
/// (found missing during a cross-source sweep — port of setUpPrivacy()).
/// Profile, credentials, offline AI model, and memory are later-phase
/// scope — see README.
struct SettingsView: View {
    @ObservedObject var historyStore: HistoryStore
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppSettings.themeKey) private var themeRaw: String = AppSettings.Theme.system.rawValue
    @AppStorage(AppSettings.searchEngineKey) private var searchEngineRaw: String = AppSettings.SearchEngine.google.rawValue
    @AppStorage(AppSettings.offlineStorageLimitMbKey) private var offlineStorageLimitMb: Int = 500

    @State private var anthropicInput: String = ""
    @State private var openAiInput: String = ""
    @State private var anthropicConfigured: Bool = false
    @State private var openAiConfigured: Bool = false
    @State private var clearedBrowsingData = false
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $themeRaw) {
                        ForEach(AppSettings.Theme.allCases) { theme in
                            Text(theme.label).tag(theme.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("themePicker")
                }

                Section("Search") {
                    Picker("Search Engine", selection: $searchEngineRaw) {
                        ForEach(AppSettings.SearchEngine.allCases) { engine in
                            Text(engine.label).tag(engine.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("searchEnginePicker")
                }

                Section("Offline Storage") {
                    Picker("Storage limit", selection: $offlineStorageLimitMb) {
                        ForEach(AppSettings.offlineStorageLimitOptionsMb, id: \.self) { mb in
                            Text(Self.byteCountFormatter.string(fromByteCount: Int64(mb) * 1024 * 1024)).tag(mb)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("offlineStorageLimitPicker")
                }

                Section("Privacy") {
                    Button(clearedBrowsingData ? "Cleared" : "Clear Browsing Data", role: .destructive) {
                        showClearConfirm = true
                    }
                    .accessibilityIdentifier("btnClearBrowsingData")
                }

                Section {
                    aiKeyRow(
                        label: "Anthropic (Claude)",
                        configured: anthropicConfigured,
                        input: $anthropicInput,
                        idPrefix: "anthropic",
                        onSave: {
                            AiSettings.setAnthropicKey(anthropicInput)
                            anthropicInput = ""
                            refreshKeyStatus()
                        },
                        onClear: {
                            AiSettings.clearAnthropicKey()
                            anthropicInput = ""
                            refreshKeyStatus()
                        }
                    )
                } header: {
                    Text("AI Providers")
                } footer: {
                    Text("Your own API key, used only to call that provider directly from this device. Stored securely in the iOS Keychain, never sent anywhere except the provider itself.")
                }

                Section {
                    aiKeyRow(
                        label: "OpenAI (ChatGPT)",
                        configured: openAiConfigured,
                        input: $openAiInput,
                        idPrefix: "openai",
                        onSave: {
                            AiSettings.setOpenAiKey(openAiInput)
                            openAiInput = ""
                            refreshKeyStatus()
                        },
                        onClear: {
                            AiSettings.clearOpenAiKey()
                            openAiInput = ""
                            refreshKeyStatus()
                        }
                    )
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("settingsDoneButton")
                }
            }
            .confirmationDialog("Clear all browsing history, cookies, and cached site data?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Clear Data", role: .destructive, action: clearBrowsingData)
                Button("Cancel", role: .cancel) {}
            }
        }
        .onAppear(perform: refreshKeyStatus)
    }

    @ViewBuilder
    private func aiKeyRow(
        label: String,
        configured: Bool,
        input: Binding<String>,
        idPrefix: String,
        onSave: @escaping () -> Void,
        onClear: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(label) — \(configured ? "Configured" : "Not configured")")
                .font(.subheadline)
                .foregroundStyle(configured ? DesignSystem.statusSuccess : DesignSystem.textMuted2)
                .accessibilityIdentifier("\(idPrefix)Status")

            SecureField("Paste your API key", text: input)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("\(idPrefix)KeyInput")

            HStack {
                Button("Save", action: onSave)
                    .disabled(input.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("\(idPrefix)SaveButton")
                Button("Clear", role: .destructive, action: onClear)
                    .disabled(!configured)
                    .accessibilityIdentifier("\(idPrefix)ClearButton")
            }
        }
        .padding(.vertical, 4)
    }

    private static let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    /// Real clear — History, cookies, and all real `WKWebsiteDataStore`
    /// site data (storage/cache), the iOS counterpart of Android's own
    /// `historyDb.clear()` + `CookieManager`/`WebStorage`/`clearCache`
    /// combination. The real per-tab `WKWebView`s stay open with their
    /// in-memory page already loaded — same real limitation Android's
    /// own cache clear has (a live WebView keeps serving what's already
    /// rendered until its next real navigation).
    private func clearBrowsingData() {
        try? historyStore.clear()
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: Date(timeIntervalSince1970: 0)
        ) {
            clearedBrowsingData = true
        }
    }

    private func refreshKeyStatus() {
        anthropicConfigured = AiSettings.getAnthropicKey() != nil
        openAiConfigured = AiSettings.getOpenAiKey() != nil
    }
}
