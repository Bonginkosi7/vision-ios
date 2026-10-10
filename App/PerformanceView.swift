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
                VStack(alignment: .leading, spacing: DesignSystem.Space.xl) {
                    documentPicker
                    DesignSystem.sectionLabel("All Topics")
                    topicsSection
                    DesignSystem.sectionLabel("Top Strengths")
                    summarySection(strongTopics, emptyText: "Keep studying — nothing's reached strong mastery yet.", emptyId: "performanceEmptyStrong", idPrefix: "performanceStrongRow_")
                    DesignSystem.sectionLabel("Needs Attention")
                    summarySection(weakTopics, emptyText: "Nothing flagged as weak right now.", emptyId: "performanceEmptyWeak", idPrefix: "performanceWeakRow_")
                }
                .padding(DesignSystem.Space.l)
            }
            .navigationTitle("Your Performance")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .visionScreen()
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
                .font(.system(size: 14)).foregroundStyle(DesignSystem.textMuted2)
                .accessibilityIdentifier("performanceEmptyTopics")
        } else {
            DesignSystem.card {
                let rows = orderedTopicRows()
                ForEach(Array(rows.enumerated()), id: \.element.topic.topicId) { index, row in
                    topicRow(row.topic, indented: row.indented)
                    if index < rows.count - 1 { DesignSystem.divider() }
                }
            }
        }
    }

    @ViewBuilder
    private func topicRow(_ topic: TopicMastery, indented: Bool) -> some View {
        HStack(spacing: DesignSystem.Space.m) {
            Text(topic.name)
                .font(.system(size: 15)).foregroundStyle(indented ? DesignSystem.textMuted2 : .white)
                .frame(maxWidth: .infinity, alignment: .leading)
            if topic.status != .notAssessed {
                masteryBar(percent: topic.masteryPercent, status: topic.status)
            }
            // Status is always stated in words as well as shown by the bar,
            // so it never depends on colour alone.
            Text(statusText(for: topic))
                .font(.system(size: 12)).foregroundStyle(statusTextColor(for: topic.status))
                .frame(minWidth: 84, alignment: .trailing)
        }
        .padding(.vertical, DesignSystem.Space.m)
        .padding(.leading, indented ? DesignSystem.Space.xl : 0)
        .accessibilityIdentifier("performanceTopicRow_\(topic.topicId)")
    }

    @ViewBuilder
    private func summarySection(_ topics: [TopicMastery], emptyText: String, emptyId: String, idPrefix: String) -> some View {
        if topics.isEmpty {
            Text(emptyText)
                .font(.system(size: 14)).foregroundStyle(DesignSystem.textMuted2)
                .accessibilityIdentifier(emptyId)
        } else {
            VStack(alignment: .leading, spacing: DesignSystem.Space.s) {
                ForEach(topics) { topic in
                    Text("\(topic.name) — \(topic.masteryPercent)%")
                        .font(.system(size: 15)).foregroundStyle(.white)
                        .accessibilityIdentifier("\(idPrefix)\(topic.topicId)")
                }
            }
        }
    }

    /// Level-1 topics each followed by their sub-topics, in display order.
    private func orderedTopicRows() -> [(topic: TopicMastery, indented: Bool)] {
        var rows: [(topic: TopicMastery, indented: Bool)] = []
        for topic in allTopics.filter({ $0.level == 1 }) {
            rows.append((topic, false))
            for sub in allTopics.filter({ $0.parentTopicId == topic.topicId }) { rows.append((sub, true)) }
        }
        return rows
    }

    private func masteryBar(percent: Int, status: MasteryStatus) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(DesignSystem.bgRaised)
                Capsule().fill(barColor(for: status))
                    .frame(width: geometry.size.width * CGFloat(min(max(percent, 0), 100)) / 100)
            }
        }
        .frame(width: 64, height: 6)
    }

    /// Red only for a weak topic (a real warning); everything else is white,
    /// dimmer while still developing.
    private func barColor(for status: MasteryStatus) -> Color {
        switch status {
        case .strong: return .white
        case .developing: return Color.white.opacity(0.55)
        case .weak: return DesignSystem.statusDangerText
        case .notAssessed: return DesignSystem.textMuted2
        }
    }

    private func statusText(for topic: TopicMastery) -> String {
        switch topic.status {
        case .strong: return "Strong · \(topic.masteryPercent)%"
        case .developing: return "Developing · \(topic.masteryPercent)%"
        case .weak: return "Weak · \(topic.masteryPercent)%"
        case .notAssessed: return "Not yet assessed"
        }
    }

    private func statusTextColor(for status: MasteryStatus) -> Color {
        status == .weak ? DesignSystem.statusDangerText : DesignSystem.textMuted2
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
