import SwiftUI
import VisionCore

/// Real per-topic mastery view — port of PerformanceActivity.kt, same
/// section structure and copy as desktop's assistant/views/performance.ts
/// (All Topics / Top Strengths / Needs Attention, same empty-state
/// wording). Reads through `PerformanceCalculator`, which is honest about
/// there being nothing to show until real flashcard reviews or marked
/// exam answers exist for a document's real extracted topics.
struct PerformanceView: View {
    @ObservedObject var studyDocumentStore: StudyDocumentStore
    @ObservedObject var topicStore: TopicStore
    @ObservedObject var flashcardStore: FlashcardStore
    @ObservedObject var examStore: ExamStore
    @Environment(\.dismiss) private var dismiss

    @State private var processedDocs: [StudyDocument] = []
    @State private var selectedDocId: String?
    @State private var allTopics: [TopicMastery] = []
    @State private var strongTopics: [TopicMastery] = []
    @State private var weakTopics: [TopicMastery] = []

    private var calculator: PerformanceCalculator {
        PerformanceCalculator(topicStore: topicStore, flashcardStore: flashcardStore, examStore: examStore, studyDocumentStore: studyDocumentStore)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    documentPicker
                    DesignSystem.sectionLabel("All Topics")
                    topicsSection
                    DesignSystem.sectionLabel("Top Strengths")
                    summarySection(strongTopics, emptyText: "Keep studying — nothing's reached strong mastery yet.", emptyId: "performanceEmptyStrong", idPrefix: "performanceStrongRow_")
                    DesignSystem.sectionLabel("Needs Attention")
                    summarySection(weakTopics, emptyText: "Nothing flagged as weak right now.", emptyId: "performanceEmptyWeak", idPrefix: "performanceWeakRow_")
                }
                .padding(16)
            }
            .background(DesignSystem.bgCanvas.ignoresSafeArea())
            .navigationTitle("Your Performance")
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
        Picker("Document", selection: Binding(get: { selectedDocId ?? "" }, set: { newValue in
            selectedDocId = newValue.isEmpty ? nil : newValue
            renderPerformance()
        })) {
            Text("All materials").tag("")
            ForEach(processedDocs) { doc in Text(doc.title).tag(doc.id) }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("performanceDocumentPicker")
    }

    @ViewBuilder
    private var topicsSection: some View {
        if allTopics.isEmpty {
            Text("No topics yet — process a document and generate flashcards or a mock test to see real performance data build up here.")
                .font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                .accessibilityIdentifier("performanceEmptyTopics")
        } else {
            VStack(alignment: .leading, spacing: 10) {
                let level1 = allTopics.filter { $0.level == 1 }
                ForEach(level1) { topic in
                    topicRow(topic, indented: false)
                    ForEach(allTopics.filter { $0.parentTopicId == topic.topicId }) { sub in
                        topicRow(sub, indented: true)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func topicRow(_ topic: TopicMastery, indented: Bool) -> some View {
        HStack(spacing: 8) {
            Text(topic.name)
                .font(.system(size: 13)).foregroundStyle(.white.opacity(indented ? 0.7 : 1))
                .frame(maxWidth: .infinity, alignment: .leading)
            ProgressView(value: Double(topic.masteryPercent), total: 100)
                .tint(color(for: topic.status))
                .frame(width: 80)
            Text(topic.status == .notAssessed ? "Not yet assessed" : "\(topic.masteryPercent)%")
                .font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2)
        }
        .padding(.leading, indented ? 24 : 0)
        .accessibilityIdentifier("performanceTopicRow_\(topic.topicId)")
    }

    @ViewBuilder
    private func summarySection(_ topics: [TopicMastery], emptyText: String, emptyId: String, idPrefix: String) -> some View {
        if topics.isEmpty {
            Text(emptyText)
                .font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                .accessibilityIdentifier(emptyId)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(topics) { topic in
                    Text("\(topic.name) — \(topic.masteryPercent)%")
                        .font(.system(size: 13)).foregroundStyle(.white)
                        .accessibilityIdentifier("\(idPrefix)\(topic.topicId)")
                }
            }
        }
    }

    private func color(for status: MasteryStatus) -> Color {
        switch status {
        case .strong: return DesignSystem.statusSuccess
        case .weak: return DesignSystem.statusDangerText
        case .developing: return DesignSystem.statDotOrange
        case .notAssessed: return DesignSystem.textMuted2
        }
    }

    private func loadDocuments() {
        processedDocs = ((try? studyDocumentStore.list()) ?? []).filter { $0.status == .processed }
        renderPerformance()
    }

    private func renderPerformance() {
        allTopics = selectedDocId.map(calculator.computeMasteryForDocument) ?? calculator.computeMasteryForAllDocuments()
        strongTopics = MasteryEngine.listStrongTopics(allTopics)
        weakTopics = MasteryEngine.listWeakTopics(allTopics)
    }
}
