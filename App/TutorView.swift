import SwiftUI
import VisionCore

private let tutorSuggestions = [
    "Explain this chapter",
    "Explain this like I'm a beginner",
    "Give me an example",
    "Summarise this section",
    "Quiz me",
]

private struct TutorExchange: Identifiable {
    let id: UUID
    let question: String
    var answerText: String?
    var sourceLabel: String?
}

/// Real AI Tutor screen — port of TutorActivity.kt/TutorLogic.kt: pick
/// "General tutoring" or a real processed document, ask a real question
/// (typed or via a suggestion chip), and get a real AI reply honestly
/// labeled by its real source (grounded in the document, general AI
/// knowledge, or — with no cloud key configured — a clearly labeled
/// "not configured" reply, never a fabricated offline answer). One
/// real `TutorStore` session persists for the life of this screen, same
/// single-conversation-per-launch scope as Android's own TutorActivity
/// (no separate past-sessions list exists on Android either).
struct TutorView: View {
    @ObservedObject var studyDocumentStore: StudyDocumentStore
    @ObservedObject var tutorStore: TutorStore
    @Environment(\.dismiss) private var dismiss

    @State private var processedDocs: [StudyDocument] = []
    @State private var selectedDocId: String?
    @State private var exchanges: [TutorExchange] = []
    @State private var askText = ""
    @State private var currentSessionId: String?
    @State private var sending = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                documentPicker
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            suggestionChips
                            ForEach(exchanges) { exchange in
                                exchangeCard(exchange)
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: exchanges.count) { _ in
                        if let last = exchanges.last { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                Divider()
                askBar
            }
            .background(DesignSystem.bgCanvas.ignoresSafeArea())
            .navigationTitle("AI Tutor")
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
        Picker("Document", selection: Binding(get: { selectedDocId ?? "" }, set: { selectedDocId = $0.isEmpty ? nil : $0 })) {
            Text("General tutoring (no document selected)").tag("")
            ForEach(processedDocs) { doc in Text(doc.title).tag(doc.id) }
        }
        .pickerStyle(.menu)
        .padding(.horizontal, 16).padding(.top, 8)
        .accessibilityIdentifier("tutorDocumentPicker")
    }

    @ViewBuilder
    private var suggestionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(tutorSuggestions.enumerated()), id: \.offset) { index, suggestion in
                    Button(suggestion) { ask(suggestion) }
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Capsule().fill(DesignSystem.bgCard))
                        .foregroundStyle(.white)
                        .accessibilityIdentifier("tutorSuggestion_\(index)")
                }
            }
        }
        .disabled(sending)
    }

    @ViewBuilder
    private func exchangeCard(_ exchange: TutorExchange) -> some View {
        DesignSystem.card {
            VStack(alignment: .leading, spacing: 6) {
                Text(exchange.question).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                    .accessibilityIdentifier("tutorQuestion_\(exchange.id)")
                if let answerText = exchange.answerText {
                    Text(answerText).font(.system(size: 13)).foregroundStyle(.white)
                        .accessibilityIdentifier("tutorAnswer_\(exchange.id)")
                    if let sourceLabel = exchange.sourceLabel {
                        Text(sourceLabel).font(.system(size: 11)).foregroundStyle(DesignSystem.textMuted2)
                            .accessibilityIdentifier("tutorSource_\(exchange.id)")
                    }
                } else {
                    Text("Thinking…").font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                        .accessibilityIdentifier("tutorThinking_\(exchange.id)")
                }
            }
        }
        .id(exchange.id)
    }

    @ViewBuilder
    private var askBar: some View {
        HStack(spacing: 8) {
            TextField("Ask about your material…", text: $askText)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(DesignSystem.bgCard))
                .foregroundStyle(.white)
                .accessibilityIdentifier("tutorAskInput")
            Button("Ask") {
                let question = askText
                askText = ""
                ask(question)
            }
            .disabled(sending)
            .accessibilityIdentifier("btnTutorAsk")
        }
        .padding(16)
        .background(DesignSystem.bgCanvas)
    }

    private func loadDocuments() {
        processedDocs = ((try? studyDocumentStore.list()) ?? []).filter { $0.status == .processed }
    }

    private func ask(_ rawQuestion: String) {
        let question = rawQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        let doc = processedDocs.first(where: { $0.id == selectedDocId })

        let exchangeId = UUID()
        exchanges.append(TutorExchange(id: exchangeId, question: question, answerText: nil, sourceLabel: nil))
        sending = true

        Task {
            let priorMessages = currentSessionId.flatMap { try? tutorStore.messagesForSession($0) } ?? []
            let history = priorMessages.map { ChatMessage(role: $0.role, content: $0.content) }
            let answer = await TutorAI.ask(question: question, history: history, documentText: doc?.extractedText)

            let sessionId: String
            if let existing = currentSessionId {
                sessionId = existing
            } else {
                let created = (try? tutorStore.createSession(documentId: doc?.id, title: String(question.prefix(60)))) ?? TutorSession(id: UUID().uuidString, documentId: doc?.id, title: question, createdAt: Date(), updatedAt: Date())
                sessionId = created.id
                currentSessionId = sessionId
            }
            try? tutorStore.addMessage(sessionId: sessionId, role: "user", content: question, groundedInDocument: nil, providerName: nil)
            try? tutorStore.addMessage(sessionId: sessionId, role: "assistant", content: answer.text, groundedInDocument: answer.groundedInDocument, providerName: answer.providerName)
            try? tutorStore.touchSession(sessionId)

            sending = false
            if let index = exchanges.firstIndex(where: { $0.id == exchangeId }) {
                exchanges[index].answerText = answer.text
                exchanges[index].sourceLabel = sourceLabel(for: answer)
            }
        }
    }

    private func sourceLabel(for answer: TutorAnswer) -> String {
        if answer.groundedInDocument { return "Based on your uploaded material" }
        if answer.providerName != nil { return "General AI knowledge" }
        return "No cloud AI configured"
    }
}
