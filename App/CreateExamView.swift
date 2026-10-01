import SwiftUI
import VisionCore

private struct DraftQuestion: Identifiable {
    let id = UUID()
    var isMCQ = true
    var prompt = ""
    var options = ["", "", "", ""]
    var correctOptionIndex: Int?
    var trueFalseAnswer: Bool?
    var explanation = ""
}

/// Real manual exam authoring — port of CreateExamActivity.kt. Supports
/// the same two hand-authored question types Android does (mcq,
/// true_false); short_answer is AI-generation-only on both platforms,
/// since a hand-authored model answer has no AI grading behind it to
/// genuinely compare against.
struct CreateExamView: View {
    @ObservedObject var examStore: ExamStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var timeLimitText = ""
    @State private var questions: [DraftQuestion] = [DraftQuestion()]
    @State private var status: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    DesignSystem.card {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Exam title", text: $title)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 10).fill(DesignSystem.bgCanvas))
                                .foregroundStyle(.white)
                                .accessibilityIdentifier("examTitleInput")
                            TextField("Time limit in minutes (optional)", text: $timeLimitText)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 10).fill(DesignSystem.bgCanvas))
                                .foregroundStyle(.white)
                                .accessibilityIdentifier("examTimeLimitInput")
                        }
                    }

                    ForEach(Array(questions.enumerated()), id: \.element.id) { index, _ in
                        questionEditor(index)
                    }

                    Button("+ Add question") { questions.append(DraftQuestion()) }
                        .accessibilityIdentifier("btnAddQuestion")

                    DesignSystem.primaryButton("Save exam") { save() }
                        .accessibilityIdentifier("btnSaveExam")

                    if let status {
                        Text(status).font(.system(size: 12)).foregroundStyle(DesignSystem.statusDangerText)
                            .accessibilityIdentifier("createExamStatus")
                    }
                }
                .padding(16)
            }
            .background(DesignSystem.bgCanvas.ignoresSafeArea())
            .navigationTitle("Create Exam")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func questionEditor(_ index: Int) -> some View {
        DesignSystem.card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Question \(index + 1)").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                    Spacer()
                    Button(action: { questions.remove(at: index) }) {
                        Image(systemName: "trash").foregroundStyle(DesignSystem.statusDangerText)
                    }
                    .accessibilityIdentifier("btnRemoveQuestion_\(index)")
                }

                Picker("Type", selection: Binding(
                    get: { questions[index].isMCQ },
                    set: { questions[index].isMCQ = $0 }
                )) {
                    Text("Multiple choice").tag(true)
                    Text("True / False").tag(false)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("questionTypePicker_\(index)")

                TextField("Question", text: Binding(get: { questions[index].prompt }, set: { questions[index].prompt = $0 }))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(DesignSystem.bgCanvas))
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("questionPrompt_\(index)")

                if questions[index].isMCQ {
                    ForEach(0..<4, id: \.self) { optionIndex in
                        HStack(spacing: 8) {
                            Button(action: { questions[index].correctOptionIndex = optionIndex }) {
                                Image(systemName: questions[index].correctOptionIndex == optionIndex ? "largecircle.fill.circle" : "circle")
                                    .foregroundStyle(DesignSystem.visionPurple)
                            }
                            .accessibilityIdentifier("mcqCorrect_\(index)_\(optionIndex)")
                            TextField("Option \(optionIndex + 1)", text: Binding(
                                get: { questions[index].options[optionIndex] },
                                set: { questions[index].options[optionIndex] = $0 }
                            ))
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 10).fill(DesignSystem.bgCanvas))
                            .foregroundStyle(.white)
                            .accessibilityIdentifier("mcqOption_\(index)_\(optionIndex)")
                        }
                    }
                } else {
                    HStack(spacing: 8) {
                        DesignSystem.primaryButton(questions[index].trueFalseAnswer == true ? "✓ True" : "True") {
                            questions[index].trueFalseAnswer = true
                        }
                        .accessibilityIdentifier("tfTrue_\(index)")
                        DesignSystem.primaryButton(questions[index].trueFalseAnswer == false ? "✓ False" : "False") {
                            questions[index].trueFalseAnswer = false
                        }
                        .accessibilityIdentifier("tfFalse_\(index)")
                    }
                }

                TextField("Explanation (optional)", text: Binding(get: { questions[index].explanation }, set: { questions[index].explanation = $0 }))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(DesignSystem.bgCanvas))
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("questionExplanation_\(index)")
            }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { status = "Give the exam a title."; return }
        guard !questions.isEmpty else { status = "Add at least one question."; return }

        var built: [RawExamQuestion] = []
        for (index, q) in questions.enumerated() {
            let prompt = q.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !prompt.isEmpty else { status = "Question \(index + 1) needs a prompt."; return }
            let explanation = q.explanation.trimmingCharacters(in: .whitespacesAndNewlines)

            if q.isMCQ {
                let options = q.options.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                guard options.allSatisfy({ !$0.isEmpty }) else { status = "Question \(index + 1) needs all 4 options filled in."; return }
                guard let correctIndex = q.correctOptionIndex else { status = "Question \(index + 1) needs a correct option selected."; return }
                built.append(RawExamQuestion(type: "mcq", prompt: prompt, options: options, correctAnswer: String(correctIndex), explanation: explanation.isEmpty ? nil : explanation))
            } else {
                guard let answer = q.trueFalseAnswer else { status = "Question \(index + 1) needs True or False selected."; return }
                built.append(RawExamQuestion(type: "true_false", prompt: prompt, options: nil, correctAnswer: answer ? "true" : "false", explanation: explanation.isEmpty ? nil : explanation))
            }
        }

        let timeLimit = Int(timeLimitText.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0 > 0 ? $0 : nil }
        try? examStore.createTest(title: trimmedTitle, timeLimitMinutes: timeLimit, questions: built)
        dismiss()
    }
}
