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
                VStack(alignment: .leading, spacing: DesignSystem.Space.l) {
                    DesignSystem.card {
                        VStack(alignment: .leading, spacing: DesignSystem.Space.m) {
                            field("Exam title", text: $title, id: "examTitleInput")
                            field("Time limit in minutes (optional)", text: $timeLimitText, id: "examTimeLimitInput", numeric: true)
                        }
                    }

                    ForEach(Array(questions.enumerated()), id: \.element.id) { index, _ in
                        questionEditor(index)
                    }

                    DesignSystem.secondaryButton("Add question", fullWidth: true) { questions.append(DraftQuestion()) }
                        .accessibilityIdentifier("btnAddQuestion")

                    DesignSystem.primaryButton("Save exam", fullWidth: true) { save() }
                        .accessibilityIdentifier("btnSaveExam")

                    if let status {
                        Text(status).font(.system(size: 13)).foregroundStyle(DesignSystem.statusDangerText)
                            .accessibilityIdentifier("createExamStatus")
                    }
                }
                .padding(DesignSystem.Space.l)
            }
            .visionScreen()
            // Dragging the form down hides the keyboard, so lower fields are never stuck under it.
            .scrollDismissesKeyboard(.interactively)
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
            VStack(alignment: .leading, spacing: DesignSystem.Space.m) {
                HStack {
                    DesignSystem.sectionLabel("Question \(index + 1)")
                    Spacer()
                    Button(action: { questions.remove(at: index) }) {
                        Image(systemName: "trash").foregroundStyle(DesignSystem.statusDangerText)
                            .frame(width: 44, height: 44)
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

                field("Question", text: Binding(get: { questions[index].prompt }, set: { questions[index].prompt = $0 }), id: "questionPrompt_\(index)")

                if questions[index].isMCQ {
                    ForEach(0..<4, id: \.self) { optionIndex in
                        HStack(spacing: 8) {
                            Button(action: { questions[index].correctOptionIndex = optionIndex }) {
                                Image(systemName: questions[index].correctOptionIndex == optionIndex ? "largecircle.fill.circle" : "circle")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                            }
                            .accessibilityLabel("Correct answer: option \(optionIndex + 1)")
                            .accessibilityAddTraits(questions[index].correctOptionIndex == optionIndex ? .isSelected : [])
                            .accessibilityIdentifier("mcqCorrect_\(index)_\(optionIndex)")
                            field("Option \(optionIndex + 1)", text: Binding(
                                get: { questions[index].options[optionIndex] },
                                set: { questions[index].options[optionIndex] = $0 }
                            ), id: "mcqOption_\(index)_\(optionIndex)")
                        }
                    }
                } else {
                    // The chosen answer is the filled button and carries the
                    // "selected" trait; the other stays outlined.
                    HStack(spacing: DesignSystem.Space.s) {
                        trueFalseButton("True", selected: questions[index].trueFalseAnswer == true, id: "tfTrue_\(index)") {
                            questions[index].trueFalseAnswer = true
                        }
                        trueFalseButton("False", selected: questions[index].trueFalseAnswer == false, id: "tfFalse_\(index)") {
                            questions[index].trueFalseAnswer = false
                        }
                    }
                }

                field("Explanation (optional)", text: Binding(get: { questions[index].explanation }, set: { questions[index].explanation = $0 }), id: "questionExplanation_\(index)")
            }
        }
    }

    private func field(_ label: String, text: Binding<String>, id: String, numeric: Bool = false) -> some View {
        TextField("", text: text, prompt: Text(label).foregroundColor(DesignSystem.textMuted2))
            .keyboardType(numeric ? .numberPad : .default)
            .visionField()
            .accessibilityLabel(label)
            .accessibilityIdentifier(id)
    }

    private func trueFalseButton(_ title: String, selected: Bool, id: String, action: @escaping () -> Void) -> some View {
        Group {
            if selected {
                DesignSystem.primaryButton(title, fullWidth: true, onClick: action)
            } else {
                DesignSystem.secondaryButton(title, fullWidth: true, onClick: action)
            }
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(id)
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
