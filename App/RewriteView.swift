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
                VStack(alignment: .leading, spacing: DesignSystem.Space.l) {
                    TextEditor(text: $inputText)
                        .scrollContentBackground(.hidden)
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .frame(minHeight: 160)
                        .padding(DesignSystem.Space.s)
                        .background(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous).fill(DesignSystem.bgRaised))
                        .accessibilityIdentifier("rewriteInput")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignSystem.Space.s) {
                            ForEach(RewriteAction.allCases) { action in
                                Button(action.label) { run(action) }
                                    .disabled(isGenerating)
                                    .font(.system(size: 14, weight: .semibold))
                                    .padding(.horizontal, DesignSystem.Space.l)
                                    .frame(minHeight: 40)
                                    .foregroundStyle(isGenerating ? DesignSystem.textMuted2 : .white)
                                    .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1))
                                    .accessibilityIdentifier("rewriteAction_\(action.rawValue)")
                            }
                        }
                    }

                    if !status.isEmpty {
                        Text(status)
                            .font(.system(size: 14))
                            .foregroundStyle(DesignSystem.textMuted2)
                            .accessibilityIdentifier("rewriteStatus")
                    }

                    if let resultText {
                        DesignSystem.card {
                            VStack(alignment: .leading, spacing: DesignSystem.Space.m) {
                                Text(resultText)
                                    .font(.system(size: 16)).lineSpacing(3)
                                    .foregroundStyle(.white)
                                    .accessibilityIdentifier("rewriteResultText")
                                if let resultSource {
                                    Text("via \(resultSource)")
                                        .font(.system(size: 12))
                                        .foregroundStyle(DesignSystem.textMuted2)
                                        .accessibilityIdentifier("rewriteResultSource")
                                }
                                HStack(spacing: DesignSystem.Space.xl) {
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
                .padding(DesignSystem.Space.l)
            }
            .visionScreen()
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
