import SwiftUI

/// Real settings — port of the slice of SettingsActivity.kt this phase's
/// scope actually needs: theme, search engine, and the two cloud AI key
/// rows (save/clear/status, same real UX pattern as
/// SettingsActivity.kt's setUpAiKeyRow). Profile, credentials, offline AI
/// model, memory, and storage are later-phase scope — see README.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppSettings.themeKey) private var themeRaw: String = AppSettings.Theme.system.rawValue
    @AppStorage(AppSettings.searchEngineKey) private var searchEngineRaw: String = AppSettings.SearchEngine.google.rawValue

    @State private var anthropicInput: String = ""
    @State private var openAiInput: String = ""
    @State private var anthropicConfigured: Bool = false
    @State private var openAiConfigured: Bool = false

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

    private func refreshKeyStatus() {
        anthropicConfigured = AiSettings.getAnthropicKey() != nil
        openAiConfigured = AiSettings.getOpenAiKey() != nil
    }
}
