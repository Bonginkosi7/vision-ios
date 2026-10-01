import SwiftUI
import VisionCore

/// Real AI-backed Paper Review screen — port of PaperReviewActivity.kt:
/// pick a real processed document, get a real spelling/grammar check,
/// honest writing feedback, and general suggestions — then optionally
/// hand the same real reviewed text straight to Rewrite Writer.
struct PaperReviewView: View {
    @ObservedObject var studyDocumentStore: StudyDocumentStore
    @Environment(\.dismiss) private var dismiss

    @State private var processedDocs: [StudyDocument] = []
    @State private var selectedDocId: String?
    @State private var reviewing = false
    @State private var status: String?
    @State private var review: PaperReview?
    @State private var lastReviewedText: String?
    @State private var showRewrite = false

    var body: some View {
        NavigationStack {
            Group {
                if processedDocs.isEmpty {
                    DesignSystem.emptyState(
                        emoji: "📄",
                        title: "No processed documents yet",
                        subtitle: "Process a document in My Materials first.",
                        ctaText: "Got it",
                        onCta: { dismiss() }
                    )
                    .accessibilityIdentifier("paperReviewNoDocuments")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DesignSystem.bgCanvas)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Pick a document you've uploaded, then get a real spelling/grammar check, honest writing feedback, and suggestions.")
                                .font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)

                            Picker("Document", selection: Binding(get: { selectedDocId ?? "" }, set: { selectedDocId = $0 })) {
                                ForEach(processedDocs) { doc in Text(doc.title).tag(doc.id) }
                            }
                            .pickerStyle(.menu)
                            .accessibilityIdentifier("paperReviewDocumentPicker")

                            DesignSystem.primaryButton(reviewing ? "Reviewing…" : "Review this document") { runReview() }
                                .disabled(reviewing)
                                .accessibilityIdentifier("btnReviewDocument")

                            if let status {
                                Text(status).font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2)
                                    .accessibilityIdentifier("paperReviewStatus")
                            }

                            if let review {
                                reviewResults(review)
                            }
                        }
                        .padding(16)
                    }
                    .background(DesignSystem.bgCanvas.ignoresSafeArea())
                }
            }
            .navigationTitle("Paper Review")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showRewrite) {
                RewriteView(initialText: lastReviewedText ?? "")
            }
        }
        .onAppear(perform: loadDocuments)
    }

    @ViewBuilder
    private func reviewResults(_ review: PaperReview) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            DesignSystem.sectionLabel("Spelling & grammar")
            if review.grammarIssues.isEmpty {
                Text("No spelling or grammar issues found.")
                    .font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                    .accessibilityIdentifier("paperReviewNoGrammarIssues")
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(review.grammarIssues.enumerated()), id: \.offset) { index, issue in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(issue.original).font(.system(size: 14)).foregroundStyle(DesignSystem.textMuted2).strikethrough()
                            Text(issue.suggestion).font(.system(size: 14)).foregroundStyle(.white)
                            if !issue.explanation.isEmpty {
                                Text(issue.explanation).font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2)
                            }
                        }
                        .accessibilityIdentifier("grammarIssue_\(index)")
                    }
                }
            }

            DesignSystem.sectionLabel("Suggestions")
            if review.improvementSuggestions.isEmpty {
                Text("No specific suggestions.")
                    .font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                    .accessibilityIdentifier("paperReviewNoSuggestions")
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(review.improvementSuggestions.enumerated()), id: \.offset) { index, suggestion in
                        Text("• \(suggestion)").font(.system(size: 14)).foregroundStyle(.white)
                            .accessibilityIdentifier("suggestion_\(index)")
                    }
                }
            }

            DesignSystem.sectionLabel("Writing review — an AI opinion, not a plagiarism database check")
            Text(review.originalityNote).font(.system(size: 13)).foregroundStyle(.white)
                .accessibilityIdentifier("originalityNote")

            DesignSystem.primaryButton("Rewrite this document →") { showRewrite = true }
                .accessibilityIdentifier("btnRewriteDocument")
        }
    }

    private func loadDocuments() {
        processedDocs = ((try? studyDocumentStore.list()) ?? []).filter { $0.status == .processed }
        if selectedDocId == nil { selectedDocId = processedDocs.first?.id }
    }

    private func runReview() {
        guard let docId = selectedDocId, let doc = processedDocs.first(where: { $0.id == docId }) else { return }
        reviewing = true
        status = "Reviewing…"
        review = nil
        Task {
            let text = doc.extractedText ?? ""
            let result = await PaperReviewer.review(documentText: text)
            lastReviewedText = text
            reviewing = false
            guard result.ok, let data = result.data else {
                status = result.error ?? "Something went wrong."
                return
            }
            status = nil
            review = data
        }
    }
}
