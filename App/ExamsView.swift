import SwiftUI
import VisionCore

/// Real Exams screen — port of ExamsActivity.kt/ExamsAdapter.kt: list every
/// real saved test (manually authored or AI-generated), create one by
/// hand, generate one from a real processed document, take one, and see
/// real local + AI-marked results.
///
/// Study-plan session integration now exists for real (see
/// `StudySessionManager`), but this screen's own entry points
/// (`btnCreateExam`/`btnGenerateExamEntry`/tapping a row) always launch
/// standalone (`sessionId` nil) — a session-backed launch instead comes
/// from `StudyPlanView`'s own "Start session" tap, which opens
/// `GenerateExamView`/`TakeExamView` directly rather than through here.
struct ExamsView: View {
    @ObservedObject var studyDocumentStore: StudyDocumentStore
    @ObservedObject var topicStore: TopicStore
    @ObservedObject var examStore: ExamStore
    @ObservedObject var rewardStore: RewardStore
    let studySessionManager: StudySessionManager
    @Environment(\.dismiss) private var dismiss

    @State private var tests: [ExamTestSummary] = []
    @State private var showCreate = false
    @State private var showGenerate = false
    @State private var openTestId: String?

    var body: some View {
        NavigationStack {
            Group {
                if tests.isEmpty {
                    DesignSystem.emptyState(
                        emoji: "📝",
                        title: "No exams yet",
                        subtitle: "Create one by hand, or generate one from a processed document.",
                        ctaText: "Got it",
                        onCta: { dismiss() }
                    )
                    .accessibilityIdentifier("emptyExamsState")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DesignSystem.bgCanvas)
                } else {
                    List {
                        ForEach(tests) { summary in
                            testRow(summary)
                        }
                    }
                    .listStyle(.plain)
                    .accessibilityIdentifier("examsList")
                }
            }
            .background(DesignSystem.bgCanvas.ignoresSafeArea())
            .navigationTitle("Exams")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 16) {
                        Button(action: { showCreate = true }) {
                            Image(systemName: "square.and.pencil")
                        }
                        .accessibilityIdentifier("btnCreateExam")
                        Button(action: { showGenerate = true }) {
                            Image(systemName: "sparkles")
                        }
                        .accessibilityIdentifier("btnGenerateExamEntry")
                    }
                }
            }
            .sheet(isPresented: $showCreate, onDismiss: refresh) {
                CreateExamView(examStore: examStore)
            }
            .sheet(isPresented: $showGenerate, onDismiss: refresh) {
                GenerateExamView(studyDocumentStore: studyDocumentStore, topicStore: topicStore, examStore: examStore)
            }
            .sheet(item: Binding(get: { openTestId.map(OpenTestId.init) }, set: { openTestId = $0?.id }), onDismiss: refresh) { wrapped in
                TakeExamView(testId: wrapped.id, examStore: examStore, rewardStore: rewardStore, studySessionManager: studySessionManager)
            }
        }
        .onAppear(perform: refresh)
    }

    private struct OpenTestId: Identifiable { let id: String }

    @ViewBuilder
    private func testRow(_ summary: ExamTestSummary) -> some View {
        let questionsLabel = "\(summary.questionCount) question\(summary.questionCount == 1 ? "" : "s")"
        let timeLabel = summary.test.timeLimitMinutes.map { " · \($0) min" } ?? " · Untimed"
        let sourceLabel = summary.test.documentId != nil ? " · AI-generated" : ""
        Button(action: { openTestId = summary.id }) {
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.test.title).foregroundStyle(.white).font(.system(size: 14, weight: .bold))
                Text(questionsLabel + timeLabel + sourceLabel)
                    .font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2)
            }
            .padding(.vertical, 8)
        }
        // One identifier on the real Button itself, not its text children
        // — matching HistoryView's own established row convention, which
        // avoids the exact container/child-identifier collision Phase 8
        // found the hard way (see MaterialsView's doc comment).
        .accessibilityIdentifier("examRow_\(summary.id)")
        .swipeActions {
            Button(role: .destructive) {
                try? examStore.deleteTest(summary.id)
                refresh()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .accessibilityIdentifier("btnDeleteExam_\(summary.id)")
        }
    }

    private func refresh() {
        tests = (try? examStore.listTests()) ?? []
    }
}
