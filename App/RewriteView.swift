import SwiftUI
import UIKit
import VisionCore

/// Real AI-backed Rewrite Writer — port of RewriteActivity.kt. The first
/// real feature to actually call CloudAIProvider (Phase 4 built the
/// infrastructure with no UI consumer; this is that consumer).
struct RewriteView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var inputText: String
    @State private var status: String = ""
    @State private var resultText: String?
    @State private var resultSource: String?
    @State private var isGenerating = false
    @State private var copyButtonLabel = "Copy"

    init(initialText: String = "") {
        _inputText = State(initialValue: initialText)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TextEditor(text: $inputText)
                        .frame(minHeight: 140)
                        .padding(8)
                        .background(DesignSystem.bgCard)
                        .cornerRadius(10)
                        .accessibilityIdentifier("rewriteInput")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(RewriteAction.allCases) { action in
                                Button(action.label) { run(action) }
                                    .disabled(isGenerating)
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(DesignSystem.brandGradient)
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                                    .accessibilityIdentifier("rewriteAction_\(action.rawValue)")
                            }
                        }
                    }

                    if !status.isEmpty {
                        Text(status)
                            .foregroundStyle(DesignSystem.textMuted2)
                            .accessibilityIdentifier("rewriteStatus")
                    }

                    if let resultText {
                        DesignSystem.card {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(resultText)
                                    .foregroundStyle(.white)
                                    .accessibilityIdentifier("rewriteResultText")
                                if let resultSource {
                                    Text("via \(resultSource)")
                                        .font(.caption)
                                        .foregroundStyle(DesignSystem.textMuted2)
                                        .accessibilityIdentifier("rewriteResultSource")
                                }
                                HStack {
                                    Button(copyButtonLabel) {
                                        UIPasteboard.general.string = resultText
                                        copyButtonLabel = "Copied"
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copyButtonLabel = "Copy" }
                                    }
                                    .accessibilityIdentifier("copyResultButton")

                                    Button("Use as Input") {
                                        inputText = resultText
                                        self.resultText = nil
                                        resultSource = nil
                                    }
                                    .accessibilityIdentifier("useAsInputButton")
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(DesignSystem.bgCanvas.ignoresSafeArea())
            .navigationTitle("Rewrite Writer")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("rewriteDoneButton")
                }
            }
        }
    }

    private func run(_ action: RewriteAction) {
        resultText = nil
        resultSource = nil
        isGenerating = true
        status = "Generating…"
        let text = inputText
        Task {
            let result = await RewriteWriter.generate(text: text, action: action)
            await MainActor.run {
                isGenerating = false
                if !result.ok || result.text == nil {
                    status = result.error ?? "Something went wrong."
                    return
                }
                status = ""
                resultText = result.text
                resultSource = result.providerName
            }
        }
    }
}
