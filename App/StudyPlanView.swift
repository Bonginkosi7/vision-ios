import SwiftUI
import VisionCore

/// "My Week" — port of StudyPlanActivity.kt: a deterministic weekly plan
/// (`StudyPlanGenerator`, no AI call) built from a student's real topic
/// mastery, with real "Start session" tracking straight into Flashcards
/// or a generated mock test. Deliberately matches desktop's own actual
/// behavior rather than a nicer imagined one — desktop's studyplan.ts
/// never auto-loads an existing plan on open either, only on a fresh
/// "Generate weekly plan" tap, so this screen starts blank until then too.
struct StudyPlanView: View {
    @ObservedObject var studyDocumentStore: StudyDocumentStore
    @ObservedObject var topicStore: TopicStore
    @ObservedObject var flashcardStore: FlashcardStore
    @ObservedObject var examStore: ExamStore
    @ObservedObject var studyPlanStore: StudyPlanStore
    @ObservedObject var rewardStore: RewardStore
    @Environment(\.dismiss) private var dismiss

    @State private var processedDocs: [StudyDocument] = []
    @State private var selectedDocId: String?
    @State private var examDate: Date?
    @State private var showDatePicker = false
    @State private var currentPlan: StudyPlan?
    @State private var currentItems: [StudyPlanItem] = []
    @State private var activeFlashcardSession: ActiveSession?
    @State private var activeExamGeneration: ActiveSession?
    @State private var activeTakeExam: ActiveTakeExam?
    @State private var showMaterialsFallback = false

    private struct ActiveSession: Identifiable {
        let id: String
        let documentId: String?
        let masteryBeforePercent: Int?
    }
    private struct ActiveTakeExam: Identifiable {
        let id: String
        let sessionId: String
        let masteryBeforePercent: Int?
    }

    private var performanceCalculator: PerformanceCalculator {
        PerformanceCalculator(topicStore: topicStore, flashcardStore: flashcardStore, examStore: examStore, studyDocumentStore: studyDocumentStore)
    }
    private var studySessionManager: StudySessionManager {
        StudySessionManager(studyPlanStore: studyPlanStore, performanceCalculator: performanceCalculator, topicStore: topicStore, rewardEngine: RewardEngine(store: rewardStore))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("A weekly plan generated from your real topic mastery — weaker topics get more sessions, automatically.")
                        .font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)

                    documentPicker
                    examDateRow
                    DesignSystem.primaryButton("Generate weekly plan") { generatePlan() }
                        .accessibilityIdentifier("btnGenerateStudyPlan")

                    if let currentPlan {
                        if let countdown = examCountdownText(currentPlan.examDate) {
                            Text(countdown).font(.system(size: 13, weight: .bold)).foregroundStyle(DesignSystem.textMuted2)
                                .accessibilityIdentifier("studyPlanExamCountdown")
                        }
                        weeklyGrid(currentPlan)
                    }
                }
                .padding(16)
            }
            .background(DesignSystem.bgCanvas.ignoresSafeArea())
            .navigationTitle("My Week")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showDatePicker) {
                datePickerSheet
            }
            .sheet(item: $activeFlashcardSession, onDismiss: refreshCurrentPlan) { session in
                FlashcardsView(
                    studyDocumentStore: studyDocumentStore, flashcardStore: flashcardStore, topicStore: topicStore,
                    studySessionManager: studySessionManager, sessionId: session.id,
                    preselectedDocumentId: session.documentId, masteryBeforePercent: session.masteryBeforePercent
                )
            }
            .sheet(item: $activeExamGeneration) { session in
                GenerateExamView(
                    studyDocumentStore: studyDocumentStore, topicStore: topicStore, examStore: examStore,
                    preselectedDocumentId: session.documentId,
                    onGenerated: { testId in activeTakeExam = ActiveTakeExam(id: testId, sessionId: session.id, masteryBeforePercent: session.masteryBeforePercent) }
                )
            }
            .sheet(item: $activeTakeExam, onDismiss: refreshCurrentPlan) { active in
                TakeExamView(
                    testId: active.id, examStore: examStore, rewardStore: rewardStore, studySessionManager: studySessionManager,
                    sessionId: active.sessionId, masteryBeforePercent: active.masteryBeforePercent
                )
            }
            .sheet(isPresented: $showMaterialsFallback) {
                MaterialsView(studyDocumentStore: studyDocumentStore, topicStore: topicStore)
            }
        }
        .onAppear(perform: loadDocuments)
    }

    @ViewBuilder
    private var documentPicker: some View {
        Picker("Document", selection: Binding(get: { selectedDocId ?? "" }, set: { selectedDocId = $0.isEmpty ? nil : $0 })) {
            Text("All materials").tag("")
            ForEach(processedDocs) { doc in Text(doc.title).tag(doc.id) }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("studyPlanDocumentPicker")
    }

    @ViewBuilder
    private var examDateRow: some View {
        HStack {
            Button(examDate.map(formattedExamDate) ?? "Exam date (optional)") { showDatePicker = true }
                .font(.system(size: 13)).foregroundStyle(.white)
                .accessibilityIdentifier("studyPlanExamDateInput")
            if examDate != nil {
                Button("Clear") { examDate = nil }
                    .font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2)
                    .accessibilityIdentifier("btnClearExamDate")
            }
        }
    }

    @ViewBuilder
    private var datePickerSheet: some View {
        NavigationStack {
            DatePicker("Exam date", selection: Binding(get: { examDate ?? Date() }, set: { examDate = $0 }), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .accessibilityIdentifier("studyPlanExamDatePicker")
                .padding()
                .navigationTitle("Exam date")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        // "Set Date", not "Done" — this sheet stacks on
                        // top of My Week's own "Done" button, and a
                        // second button with the same label would make
                        // `app.navigationBars.buttons["Done"]` ambiguous
                        // in a UI test, the same reason TakeExamView's
                        // own dismiss button is labeled "Close" instead.
                        Button("Set Date") { showDatePicker = false }
                    }
                }
                // Commits "today" into `examDate` the moment the sheet
                // opens — matching Android's own DatePickerDialog, which
                // pre-populates the current year/month/day into its
                // fields immediately rather than requiring an explicit
                // scroll/tap first. Without this, a user (or a UI test)
                // that opens the picker and taps "Set Date" without
                // touching the calendar grid would see `examDate` stay
                // nil, since a SwiftUI DatePicker's binding `set` only
                // fires on a real user interaction with the control.
                .onAppear {
                    if examDate == nil { examDate = Date() }
                }
        }
    }

    @ViewBuilder
    private func weeklyGrid(_ plan: StudyPlan) -> some View {
        if currentItems.isEmpty {
            Text("No topics available yet to build a plan from — process a document first.")
                .font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                .accessibilityIdentifier("studyPlanEmpty")
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(0..<7, id: \.self) { offset in
                    dayCard(plan, offset: offset)
                }
            }
        }
    }

    @ViewBuilder
    private func dayCard(_ plan: StudyPlan, offset: Int) -> some View {
        let dayDate = plan.weekStartAt.addingTimeInterval(Double(offset) * 24 * 60 * 60)
        let items = currentItems.filter { $0.dayOffset == offset }
        DesignSystem.card {
            VStack(alignment: .leading, spacing: 8) {
                Text(formattedDay(dayDate)).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                if items.isEmpty {
                    Text("Rest / review").font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                } else {
                    ForEach(items) { item in
                        planItemRow(item)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func planItemRow(_ item: StudyPlanItem) -> some View {
        let topicName = item.topicId.flatMap { try? topicStore.get($0) }?.name
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(activityLabel(item.activityType) + (topicName.map { " — \($0)" } ?? ""))
                    .font(.system(size: 13)).foregroundStyle(.white)
                if item.completedAt != nil {
                    Text("Done").font(.system(size: 11)).foregroundStyle(DesignSystem.textMuted2)
                        .accessibilityIdentifier("studyPlanItemDone_\(item.id)")
                }
            }
            Text(item.rationale).font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2)
            if item.completedAt == nil {
                Button("Start session") { startSession(item) }
                    .font(.system(size: 11, weight: .bold))
                    .accessibilityIdentifier("btnStartSession_\(item.id)")
            }
        }
        .padding(.vertical, 4)
    }

    private func activityLabel(_ type: EduPlanActivityType) -> String {
        switch type {
        case .flashcards: return "Flashcards"
        case .mockTest: return "Mock Test"
        case .reviewWeakTopic: return "Focused Review"
        case .readMaterial: return "Read Material"
        }
    }

    private func formattedDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    private func formattedExamDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        return formatter.string(from: date)
    }

    private func examCountdownText(_ examDate: Date?) -> String? {
        guard let examDate else { return nil }
        let daysLeft = Int((examDate.timeIntervalSinceNow / (24 * 60 * 60)).rounded(.up))
        if daysLeft >= 0 {
            return "Exam in \(daysLeft) day\(daysLeft == 1 ? "" : "s")."
        }
        return "Exam date has passed."
    }

    /// A "Start session" tap may have just marked an item complete in a
    /// just-dismissed sheet — reload the same real plan to reflect it,
    /// matching Android's own `onResume()` refresh.
    private func refreshCurrentPlan() {
        guard let currentPlan else { return }
        currentItems = (try? studyPlanStore.getPlan(currentPlan.id))?.items ?? []
    }

    private func loadDocuments() {
        processedDocs = ((try? studyDocumentStore.list()) ?? []).filter { $0.status == .processed }
    }

    private func startOfToday() -> Date {
        Calendar.current.startOfDay(for: Date())
    }

    private func generatePlan() {
        let documentId = selectedDocId
        let allMastery = documentId.map(performanceCalculator.computeMasteryForDocument) ?? performanceCalculator.computeMasteryForAllDocuments()
        let topLevel = allMastery.filter { $0.level == 1 }
        let weekStartAt = startOfToday()
        let items = StudyPlanGenerator.generateWeeklyPlan(topics: topLevel, examDate: examDate, weekStartAt: weekStartAt)
        guard let plan = try? studyPlanStore.createPlan(documentId: documentId, examDate: examDate, weekStartAt: weekStartAt, items: items) else { return }
        currentPlan = plan
        currentItems = (try? studyPlanStore.getPlan(plan.id))?.items ?? []
    }

    private func startSession(_ item: StudyPlanItem) {
        let documentId = selectedDocId
        let result = studySessionManager.startSession(documentId: documentId, topicId: item.topicId, activityType: item.activityType, planItemId: item.id)

        switch item.activityType {
        case .flashcards, .reviewWeakTopic:
            activeFlashcardSession = ActiveSession(id: result.session.id, documentId: documentId, masteryBeforePercent: result.masteryBeforePercent)
        case .mockTest:
            activeExamGeneration = ActiveSession(id: result.session.id, documentId: documentId, masteryBeforePercent: result.masteryBeforePercent)
        case .readMaterial:
            // Never actually produced by StudyPlanGenerator today — routed
            // to the real document list as the closest honest equivalent,
            // rather than a dead button, should this type ever appear.
            showMaterialsFallback = true
        }
    }
}
