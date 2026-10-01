import SwiftUI
import VisionCore

/// Real flashcards screen — port of FlashcardsActivity.kt: pick a real
/// processed document, generate real AI flashcards from its real
/// extracted text (optionally tagged against its real extracted topics),
/// review the real due queue with the same Leitner-style schedule as
/// desktop, and see every real card's own review stats.
///
/// Android's study-plan session integration (`sessionId`/
/// `completeCurrentSession`/`StudySessionLogic`) is deliberately not
/// ported — Study Plan doesn't exist on iOS yet (see README's disclosed
/// scope trim). This is the plain, standalone Flashcards experience
/// Android itself has when reached outside of a study-plan session.
struct FlashcardsView: View {
    @ObservedObject var studyDocumentStore: StudyDocumentStore
    @ObservedObject var flashcardStore: FlashcardStore
    @ObservedObject var topicStore: TopicStore
    @Environment(\.dismiss) private var dismiss

    @State private var processedDocs: [StudyDocument] = []
    @State private var selectedDocId: String?
    @State private var countText = "10"
    @State private var generating = false
    @State private var generateStatus: String?
    @State private var dueQueue: [Flashcard] = []
    @State private var dueIndex = 0
    @State private var cardFlipped = false
    @State private var allCards: [Flashcard] = []

    var body: some View {
        NavigationStack {
            Group {
                if processedDocs.isEmpty {
                    DesignSystem.emptyState(
                        emoji: "🃏",
                        title: "No processed material yet",
                        subtitle: "Process a document in My Materials first.",
                        ctaText: "Got it",
                        onCta: { dismiss() }
                    )
                    .accessibilityIdentifier("emptyFlashcardsState")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DesignSystem.bgCanvas)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            documentPicker
                            generateSection
                            DesignSystem.sectionLabel("Due for review")
                            reviewArea
                            DesignSystem.sectionLabel("All flashcards")
                            allCardsList
                        }
                        .padding(16)
                    }
                    .background(DesignSystem.bgCanvas.ignoresSafeArea())
                }
            }
            .background(DesignSystem.bgCanvas.ignoresSafeArea())
            .navigationTitle("Flashcards")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear(perform: loadDocuments)
    }

    @ViewBuilder
    private var documentPicker: some View {
        Picker("Document", selection: Binding(
            get: { selectedDocId ?? "" },
            set: { newId in
                selectedDocId = newId
                loadForSelectedDocument()
            }
        )) {
            ForEach(processedDocs) { doc in
                Text(doc.title).tag(doc.id)
            }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("flashcardsDocumentPicker")
    }

    @ViewBuilder
    private var generateSection: some View {
        DesignSystem.card {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Count", text: $countText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(DesignSystem.bgCanvas))
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("flashcardsCountInput")
                DesignSystem.primaryButton(generating ? "Generating…" : "Generate flashcards") { generate() }
                    .disabled(generating)
                    .accessibilityIdentifier("btnGenerateFlashcards")
                if let generateStatus {
                    Text(generateStatus)
                        .font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2)
                        .accessibilityIdentifier("flashcardsGenerateStatus")
                }
            }
        }
    }

    @ViewBuilder
    private var reviewArea: some View {
        if dueQueue.isEmpty {
            Text("Nothing due right now.")
                .font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                .accessibilityIdentifier("flashcardsNothingDue")
        } else if dueIndex >= dueQueue.count {
            Text("You're caught up — no more cards due right now.")
                .font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                .accessibilityIdentifier("flashcardsCaughtUp")
        } else {
            let card = dueQueue[dueIndex]
            VStack(alignment: .leading, spacing: 8) {
                Button(action: { cardFlipped.toggle() }) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(cardFlipped ? "Back" : "Front — tap to reveal")
                            .font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2)
                        Text(cardFlipped ? card.back : card.front)
                            .font(.system(size: 17)).foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(DesignSystem.bgCard))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(DesignSystem.borderCard, lineWidth: 1))
                .accessibilityIdentifier("flashcardFlipCard")

                Text("Card \(dueIndex + 1) of \(dueQueue.count)")
                    .font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2)
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack(spacing: 8) {
                    DesignSystem.primaryButton("Still learning") { review(card.id, confident: false) }
                        .accessibilityIdentifier("btnStillLearning")
                    DesignSystem.primaryButton("I know it") { review(card.id, confident: true) }
                        .accessibilityIdentifier("btnKnowIt")
                }
            }
        }
    }

    @ViewBuilder
    private var allCardsList: some View {
        if allCards.isEmpty {
            Text("No flashcards yet — generate some above.")
                .font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                .accessibilityIdentifier("flashcardsNoneYet")
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(allCards) { card in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.front).font(.system(size: 14)).foregroundStyle(.white)
                            .accessibilityIdentifier("flashcardFront_\(card.id)")
                        Text("\(card.reviewCount) review\(card.reviewCount == 1 ? "" : "s") · every \(max(card.intervalDays, 1))d")
                            .font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2)
                    }
                }
            }
        }
    }

    private func loadDocuments() {
        processedDocs = ((try? studyDocumentStore.list()) ?? []).filter { $0.status == .processed }
        if selectedDocId == nil || !processedDocs.contains(where: { $0.id == selectedDocId }) {
            selectedDocId = processedDocs.first?.id
        }
        loadForSelectedDocument()
    }

    private func loadForSelectedDocument() {
        guard let docId = selectedDocId else {
            dueQueue = []
            allCards = []
            return
        }
        dueQueue = (try? flashcardStore.dueForDocument(docId)) ?? []
        dueIndex = 0
        cardFlipped = false
        allCards = (try? flashcardStore.listForDocument(docId)) ?? []
    }

    private func generate() {
        guard let docId = selectedDocId, let doc = processedDocs.first(where: { $0.id == docId }) else { return }
        let count = Int(countText) ?? 10
        generating = true
        generateStatus = "Generating flashcards…"
        Task {
            let text = doc.extractedText ?? ""
            let topics = ((try? topicStore.listForDocument(docId)) ?? []).map { TopicRef(id: $0.id, name: $0.name) }
            let result = await FlashcardGenerator.generate(documentText: text, count: count, topics: topics)
            generating = false
            guard result.ok, let data = result.data else {
                generateStatus = result.error ?? "Couldn't generate flashcards."
                return
            }
            let created = (try? flashcardStore.createMany(
                documentId: docId, cards: data.map { NewFlashcard(front: $0.front, back: $0.back, topicId: $0.topicId) }
            )) ?? []
            generateStatus = "Generated \(created.count) flashcards."
            loadForSelectedDocument()
        }
    }

    private func review(_ cardId: String, confident: Bool) {
        try? flashcardStore.markReviewed(cardId, confident: confident)
        dueIndex += 1
        cardFlipped = false
        if let docId = selectedDocId {
            allCards = (try? flashcardStore.listForDocument(docId)) ?? []
        }
    }
}
