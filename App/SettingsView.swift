import SwiftUI
import VisionCore
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
    @AppStorage(AppSettings.analyticsEnabledKey) private var analyticsEnabled: Bool = true
    @AppStorage(AppSettings.diagnosticsEnabledKey) private var diagnosticsEnabled: Bool = true

    @State private var anthropicInput: String = ""
    @State private var openAiInput: String = ""
    @State private var anthropicConfigured: Bool = false
    @State private var openAiConfigured: Bool = false
    @State private var clearedBrowsingData = false
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                // Section header text matches Android's own bold labels verbatim
                // (settings_theme = "Theme", settings_search_engine =
                // "Default search engine", settings_offline_storage = "Offline
                // storage", settings_ai_providers = "Cloud AI providers") —
                // Android has no generic "Appearance"/"Search" supersection, so
                // inventing those names here would be a real grouping mismatch.
                Section("Theme") {
                    Picker("Theme", selection: $themeRaw) {
                        ForEach(AppSettings.Theme.allCases) { theme in
                            Text(theme.label).tag(theme.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("themePicker")
                }

                Section("Default search engine") {
                    Picker("Search Engine", selection: $searchEngineRaw) {
                        ForEach(AppSettings.SearchEngine.allCases) { engine in
                            Text(engine.label).tag(engine.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("searchEnginePicker")
                }

                Section {
                    Picker("Storage limit", selection: $offlineStorageLimitMb) {
                        ForEach(AppSettings.offlineStorageLimitOptionsMb, id: \.self) { mb in
                            Text(Self.byteCountFormatter.string(fromByteCount: Int64(mb) * 1024 * 1024)).tag(mb)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("offlineStorageLimitPicker")
                } header: {
                    Text("Offline storage")
                } footer: {
                    // Verbatim port of settings_storage_limit_desc.
                    Text("A cap for your own reference. Nothing here pre-caches or auto-saves pages, so there's no lower-priority content to remove automatically when you're over — every saved page is an explicit save.")
                }

                Section {
                    // Android's own Clear browsing data button is a plain
                    // OutlinedButton (brand-purple, never red) — no
                    // statusDangerText anywhere on this screen — so this is a
                    // plain default-role button, not SwiftUI's red .destructive.
                    Button(clearedBrowsingData ? "Cleared" : "Clear Data") {
                        showClearConfirm = true
                    }
                    .accessibilityIdentifier("btnClearBrowsingData")

                    // Android's setUpPrivacy() puts these same two checkboxes
                    // in this same Privacy card, right below Clear Browsing
                    // Data — matched here rather than inventing a separate
                    // "Analytics" section Android itself doesn't have.
                    Toggle("Anonymous usage analytics", isOn: $analyticsEnabled)
                        .accessibilityIdentifier("analyticsEnabledToggle")
                    Text("Help improve VISION by sharing anonymous product usage statistics — which features get used, not what you browse. We never collect your browsing history, page contents, passwords, or search queries with this.")
                        .font(.caption).foregroundStyle(.secondary)

                    Toggle("Technical diagnostics", isOn: $diagnosticsEnabled)
                        .accessibilityIdentifier("diagnosticsEnabledToggle")
                    Text("Share anonymous crash and performance reports to help fix bugs. Never includes page content.")
                        .font(.caption).foregroundStyle(.secondary)
                } header: {
                    Text("Privacy")
                } footer: {
                    // Verbatim port of settings_clear_browsing_data_desc.
                    Text("Deletes local history and site storage (cookies, cache) for this app.")
                }

                // Android groups both key rows under ONE "Cloud AI providers"
                // header/description, OpenAI first then Anthropic (see
                // SettingsActivity.onCreate and activity_settings.xml row
                // order) — previously these were two separate sections, with
                // Anthropic first and OpenAI carrying no header at all.
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
                    Text("Cloud AI providers")
                } footer: {
                    Text("Your own API key, used only to call that provider directly from this device. Stored securely in the iOS Keychain, never sent anywhere except the provider itself.")
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
                // Android's AlertDialog positive/negative buttons are both
                // plain theme-colored text, never red — matched here with
                // default-role buttons instead of SwiftUI's red .destructive.
                //
                // Real CI bug found here: with no explicit identifier, this
                // button's default (label-derived) identifier collided with
                // the row button above it ("Clear Data" vs. "Clear Data") —
                // app.buttons["Clear Data"] matched two elements. A plain
                // .destructive-role button happened to avoid this (its
                // accessibility node is styled/exposed differently), but
                // this screen deliberately isn't using that role (see
                // above) — so this needs its own explicit identifier
                // instead of relying on the same label text both buttons
                // share.
                Button("Clear Data", action: clearBrowsingData)
                    .accessibilityIdentifier("confirmClearDataButton")
                Button("Cancel", role: .cancel) {}
            }
        }
        .onAppear {
            refreshKeyStatus()
            // Real call site, matching SettingsActivity.kt's own
            // AnalyticsClient.track(this, AnalyticsEvent.SETTINGS_OPENED) —
            // proves the queue/flush plumbing end to end, not just the
            // app-launch lifecycle events AnalyticsClient.start() already
            // fires on its own. Every other screen's own track() call is
            // separate follow-up scope (see AnalyticsEvent.swift).
            AnalyticsClient.shared.track(AnalyticsEvent.settingsOpened)
        }
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
            // Android's setUpAiKeyRow writes this status text in the plain
            // default TextView color regardless of configured/not-configured
            // state — no green "success" or muted-dark tint. DesignSystem's
            // statusSuccess/textMuted2 are Phase-30 dark-card tokens meant for
            // screens built on bgCanvas/bgCard, not this plain system Form, so
            // color-coding this label here was an invented divergence.
            Text("\(label) — \(configured ? "Configured" : "Not configured")")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("\(idPrefix)Status")

            SecureField("Paste your API key", text: input)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("\(idPrefix)KeyInput")

            HStack {
                Button("Save", action: onSave)
                    .disabled(input.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("\(idPrefix)SaveButton")
                // Android's Clear button is a plain TextButton (brand-colored,
                // never red) — matched with a default-role Button here.
                Button("Clear", action: onClear)
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
