import SwiftUI
import VisionCore

/// Real exam-taking screen — port of TakeExamActivity.kt: render every
/// real question, submit real answers, mark MCQ/true-false instantly and
/// locally (ExamMarking), batch-mark short-answer questions with one real
/// AI call (ShortAnswerMarker), and award a real `eduTestCompleted` point
/// event once the whole attempt is genuinely, fully marked.
///
/// The post-submission study-plan confidence prompt
/// (`sessionConfidenceContainer`/`StudySessionLogic.completeSession`) now
/// exists for real — `sessionId`/`masteryBeforePercent` are only ever set
/// when this view is reached via GenerateExamView's own session hand-off
/// from StudyPlanView's "Start session" tap; standalone use from the
/// Exams list leaves them nil.
struct TakeExamView: View {
    let testId: String
    @ObservedObject var examStore: ExamStore
    @ObservedObject var rewardStore: RewardStore
    let studySessionManager: StudySessionManager
    var sessionId: String?
    var masteryBeforePercent: Int?
    @Environment(\.dismiss) private var dismiss
    @State private var sessionCompleted = false

    @State private var test: ExamTest?
    @State private var questions: [ExamQuestionRecord] = []
    @State private var attempt: ExamAttempt?
    @State private var mcqAnswers: [String: Int] = [:]
    @State private var trueFalseAnswers: [String: Bool] = [:]
    @State private var shortAnswers: [String: String] = [:]
    @State private var submitted = false
    @State private var results: [ExamAnswerResult] = []
    @State private var pendingCount = 0
    @State private var marking = false
    @State private var now = Date()
    // @State, deliberately, not a plain `let` — see FocusView's own doc
    // comment on this exact Timer.publish gotcha.
    @State private var tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            Group {
                if let test {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if let expiresAt = attempt?.expiresAt, !submitted {
                                Text(remainingTimeLabel(expiresAt))
                                    .font(.system(size: 13, weight: .bold)).foregroundStyle(DesignSystem.textMuted2)
                                    .accessibilityIdentifier("takeExamTimer")
                            }
                            if submitted {
                                resultsHeader
                            } else {
                                ForEach(questions) { question in
                                    questionRow(question)
                                }
                                DesignSystem.primaryButton("Submit") { submit() }
                                    .accessibilityIdentifier("btnSubmitExam")
                            }
                        }
                        .padding(16)
                    }
                    .background(DesignSystem.bgCanvas.ignoresSafeArea())
                    .navigationTitle(test.title)
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(DesignSystem.bgCanvas.ignoresSafeArea())
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // No explicit identifier — matching every other plain-
                    // text "Done"/"Cancel" dismiss button in this codebase,
                    // whose default identifier (the visible label itself)
                    // is what the UI tests already look these up by.
                    Button("Close") { dismiss() }
                }
            }
        }
        .onReceive(tick) { tickDate in
            now = tickDate
            if let expiresAt = attempt?.expiresAt, !submitted, tickDate >= expiresAt {
                submit()
            }
        }
        .onAppear(perform: load)
    }

    @ViewBuilder
    private func questionRow(_ question: ExamQuestionRecord) -> some View {
        DesignSystem.card {
            VStack(alignment: .leading, spacing: 10) {
                Text(question.prompt).font(.system(size: 14)).foregroundStyle(.white)
                    .accessibilityIdentifier("takingPrompt_\(question.id)")

                if question.type == "short_answer" {
                    TextField("Type your answer…", text: Binding(
                        get: { shortAnswers[question.id] ?? "" },
                        set: { shortAnswers[question.id] = $0 }
                    ))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(DesignSystem.bgCanvas))
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("takingShortAnswerInput_\(question.id)")
                } else if question.type == "mcq" {
                    ForEach(Array((question.options ?? []).enumerated()), id: \.offset) { index, optionText in
                        optionButton(label: optionText, selected: mcqAnswers[question.id] == index, id: "takingOption_\(question.id)_\(index)") {
                            mcqAnswers[question.id] = index
                        }
                    }
                } else {
                    HStack(spacing: 8) {
                        optionButton(label: "True", selected: trueFalseAnswers[question.id] == true, id: "takingTrue_\(question.id)") {
                            trueFalseAnswers[question.id] = true
                        }
                        optionButton(label: "False", selected: trueFalseAnswers[question.id] == false, id: "takingFalse_\(question.id)") {
                            trueFalseAnswers[question.id] = false
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func optionButton(label: String, selected: Bool, id: String, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(DesignSystem.visionPurple)
                Text(label).foregroundStyle(.white)
                Spacer()
            }
        }
        .accessibilityIdentifier(id)
    }

    @ViewBuilder
    private var resultsHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(scoreLabel)
                .font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                .accessibilityIdentifier("resultsScore")

            if pendingCount > 0 {
                Text("\(pendingCount) answer\(pendingCount == 1 ? "" : "s") awaiting AI marking")
                    .font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2)
                    .accessibilityIdentifier("resultsPendingStatus")
                if !marking {
                    Button("Retry marking") { runShortAnswerMarking() }
                        .accessibilityIdentifier("btnRetryMarking")
                }
            }

            ForEach(results) { result in
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.prompt).font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                        .accessibilityIdentifier("resultPrompt_\(result.questionId)")
                    if result.isCorrect == nil {
                        Text("Your answer: \(result.studentAnswer.isEmpty ? "(no answer)" : result.studentAnswer)")
                            .font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2)
                        Text("Pending AI marking…")
                            .font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2)
                            .accessibilityIdentifier("resultFeedback_\(result.questionId)")
                    } else {
                        Text(result.feedback ?? "")
                            .font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2)
                            .accessibilityIdentifier("resultFeedback_\(result.questionId)")
                    }
                }
                .padding(.vertical, 4)
            }

            if sessionId != nil, !results.isEmpty, results.allSatisfy({ $0.isCorrect != nil }) {
                SessionConfidencePrompt(completed: sessionCompleted, onRate: completeSession)
            }
        }
    }

    private var scoreLabel: String {
        if results.allSatisfy({ $0.isCorrect != nil }) {
            let percent = ExamMarking.scorePercent(correctCount: results.filter { $0.isCorrect == true }.count, totalAnswers: results.count)
            return "\(Int(percent.rounded()))% correct"
        }
        return "Marking your test…"
    }

    private func remainingTimeLabel(_ expiresAt: Date) -> String {
        let remaining = max(0, expiresAt.timeIntervalSince(now))
        let mins = Int(remaining) / 60
        let secs = Int(remaining) % 60
        return String(format: "%d:%02d remaining", mins, secs)
    }

    private func load() {
        guard let loadedTest = try? examStore.getTest(testId) else { dismiss(); return }
        test = loadedTest
        questions = (try? examStore.questionsForTest(testId)) ?? []
        attempt = try? examStore.startAttempt(testId: testId, timeLimitMinutes: loadedTest.timeLimitMinutes)
    }

    private func submit() {
        guard !submitted, let attempt else { return }
        submitted = true

        var answers: [String: String] = [:]
        for (questionId, index) in mcqAnswers { answers[questionId] = String(index) }
        for (questionId, value) in trueFalseAnswers { answers[questionId] = value ? "true" : "false" }
        for (questionId, text) in shortAnswers { answers[questionId] = text }

        try? examStore.submitAttempt(attemptId: attempt.id, testId: testId, answers: answers)
        refreshResults()
        runShortAnswerMarking()
    }

    private func runShortAnswerMarking() {
        guard let attempt else { return }
        guard let pending = try? examStore.pendingShortAnswers(attemptId: attempt.id), !pending.isEmpty else {
            finalizeAndRender()
            return
        }

        marking = true
        Task {
            let toMark = pending.map { PendingShortAnswer(questionId: $0.question.id, prompt: $0.question.prompt, modelAnswer: $0.question.correctAnswer, studentAnswer: $0.answer.studentAnswer) }
            let markingResults = await ShortAnswerMarker.mark(toMark)
            for result in markingResults ?? [] {
                try? examStore.markAnswer(attemptId: attempt.id, questionId: result.questionId, isCorrect: result.isCorrect, feedback: result.feedback)
            }
            marking = false
            finalizeAndRender()
        }
    }

    private func finalizeAndRender() {
        guard let attempt else { return }
        let scorePercent = try? examStore.finalizeIfComplete(attempt.id)
        refreshResults()

        if let scorePercent {
            RewardEngine(store: rewardStore).awardIfEligible(type: .eduTestCompleted, note: "Completed a mock test (\(Int(scorePercent.rounded()))%)")
        }
    }

    private func refreshResults() {
        guard let attempt else { return }
        results = (try? examStore.answersForAttempt(attempt.id)) ?? []
        pendingCount = results.filter { $0.isCorrect == nil }.count
    }

    private func completeSession(confidenceRating: Int) {
        guard let sessionId else { return }
        _ = studySessionManager.completeSession(sessionId: sessionId, confidenceRating: confidenceRating, masteryBeforePercent: masteryBeforePercent)
        sessionCompleted = true
    }
}
