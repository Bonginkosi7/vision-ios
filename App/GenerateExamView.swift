import SwiftUI
import VisionCore

/// Real AI-generated exam — port of GenerateExamActivity.kt: pick a real
/// processed document, choose how many of each question type, and
/// generate a real test grounded in that document's real extracted text
/// (optionally tagged against its real extracted topics, same
/// `TopicTagging` plumbing as Flashcards).
///
/// Android's study-plan launch path (`sessionId`/`masteryBeforePercent`,
/// jumping straight into `TakeExamActivity` instead of back to the Exams
/// list) now exists for real: when `onGenerated` is provided (only when
/// launched from StudyPlanView's "Start session" tap), a successful
/// generation calls it with the new test id and dismisses this screen,
/// so the presenter can open `TakeExamView` directly with the same
/// session carried over — the real equivalent of Android starting
/// `TakeExamActivity` then finishing `GenerateExamActivity`. Standalone
/// use from the Exams list leaves `onGenerated` nil and just dismisses
/// back to the Exams list, same as Android's own no-session path.
struct GenerateExamView: View {
    @ObservedObject var studyDocumentStore: StudyDocumentStore
    @ObservedObject var topicStore: TopicStore
    @ObservedObject var examStore: ExamStore
    var preselectedDocumentId: String?
    var onGenerated: ((String) -> Void)?
    @Environment(\.dismiss) private var dismiss

    @State private var processedDocs: [StudyDocument] = []
    @State private var selectedDocId: String?
    @State private var titleText = ""
    @State private var timeLimitText = ""
    @State private var mcqCountText = "3"
    @State private var tfCountText = "2"
    @State private var shortCountText = "0"
    @State private var generating = false
    @State private var status: String?

    var body: some View {
        NavigationStack {
            Group {
                if processedDocs.isEmpty {
                    DesignSystem.emptyState(
                        title: "No processed material yet",
                        subtitle: "Process a document in My Materials first.",
                        ctaText: "Got it",
                        onCta: { dismiss() }
                    )
                    .accessibilityIdentifier("generateExamNoDocuments")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: DesignSystem.Space.l) {
                            Picker("Document", selection: Binding(get: { selectedDocId ?? "" }, set: { selectedDocId = $0 })) {
                                ForEach(processedDocs) { doc in Text(doc.title).tag(doc.id) }
                            }
                            .pickerStyle(.menu)
                            .accessibilityIdentifier("generateExamDocumentPicker")

                            DesignSystem.card {
                                VStack(alignment: .leading, spacing: DesignSystem.Space.m) {
                                    labeledField("Exam title (optional)", text: $titleText, id: "generateExamTitleInput")
                                    labeledField("Time limit in minutes (optional)", text: $timeLimitText, id: "generateExamTimeLimitInput", numeric: true)
                                    labeledField("MCQ", text: $mcqCountText, id: "generateExamMcqCount", numeric: true)
                                    labeledField("True/False", text: $tfCountText, id: "generateExamTfCount", numeric: true)
                                    labeledField("Short answer", text: $shortCountText, id: "generateExamShortCount", numeric: true)
                                    DesignSystem.primaryButton(generating ? "Generating…" : "Generate Mock Test", fullWidth: true) { generate() }
                                        .disabled(generating)
                                        .accessibilityIdentifier("btnGenerateExam")
                                    if let status {
                                        Text(status).font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                                            .accessibilityIdentifier("generateExamStatus")
                                    }
                                }
                            }
                        }
                        .padding(DesignSystem.Space.l)
                    }
                }
            }
            .visionScreen()
            .navigationTitle("Generate Mock Test")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear(perform: loadDocuments)
    }

    @ViewBuilder
    private func labeledField(_ label: String, text: Binding<String>, id: String, numeric: Bool = false) -> some View {
        TextField("", text: text, prompt: Text(label).foregroundColor(DesignSystem.textMuted2))
            .keyboardType(numeric ? .numberPad : .default)
            .visionField()
            .accessibilityLabel(label)
            .accessibilityIdentifier(id)
    }

    private func loadDocuments() {
        processedDocs = ((try? studyDocumentStore.list()) ?? []).filter { $0.status == .processed }
        if selectedDocId == nil {
            let preselected = preselectedDocumentId.flatMap { id in processedDocs.first { $0.id == id } }
            selectedDocId = preselected?.id ?? processedDocs.first?.id
        }
    }

    private func generate() {
        guard let docId = selectedDocId, let doc = processedDocs.first(where: { $0.id == docId }) else { return }
        let counts = ExamGenerationCounts(
            mcq: Int(mcqCountText) ?? 0,
            trueFalse: Int(tfCountText) ?? 0,
            shortAnswer: Int(shortCountText) ?? 0
        )
        let timeLimit = Int(timeLimitText.trimmingCharacters(in: .whitespacesAndNewlines))
        let title = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = title.isEmpty ? doc.title : title

        generating = true
        status = "Generating…"
        Task {
            let text = doc.extractedText ?? ""
            let topics = ((try? topicStore.listForDocument(docId)) ?? []).map { TopicRef(id: $0.id, name: $0.name) }
            let result = await ExamGenerator.generate(documentText: text, counts: counts, topics: topics)
            generating = false
            guard result.ok, let data = result.data else {
                status = result.error ?? "Couldn't generate a test."
                return
            }
            let testId = try? examStore.createTest(title: resolvedTitle, timeLimitMinutes: timeLimit, questions: data, documentId: doc.id)
            if let onGenerated, let testId {
                onGenerated(testId)
            }
            dismiss()
        }
    }
}
