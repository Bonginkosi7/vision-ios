import SwiftUI

/// Real personal task list — port of TasksActivity.kt. Binary open/
/// completed only, no fabricated "in progress" state (matches the real
/// Android/desktop data model); completion is one-way, enforced by
/// TaskStore.complete's own "was this actually still open" guard — a
/// completed task can't be tapped back to pending here.
struct TasksView: View {
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var rewardStore: RewardStore
    @Environment(\.dismiss) private var dismiss

    private enum Filter: String, CaseIterable { case all = "All", pending = "Pending", completed = "Completed" }

    @State private var tasks: [ProductivityTask] = []
    @State private var filter: Filter = .all
    @State private var newTaskTitle = ""

    private var filteredTasks: [ProductivityTask] {
        switch filter {
        case .all: return tasks
        case .pending: return tasks.filter { $0.completedAt == nil }
        case .completed: return tasks.filter { $0.completedAt != nil }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: DesignSystem.Space.s) {
                    TextField("", text: $newTaskTitle, prompt: Text("Add a task").foregroundColor(DesignSystem.textMuted2))
                        .onSubmit(addTask)
                        .visionField()
                        .accessibilityLabel("Add a task")
                        .accessibilityIdentifier("newTaskField")
                    Button(action: addTask) {
                        Text("Add")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty ? DesignSystem.textMuted2 : .white)
                            .padding(.horizontal, DesignSystem.Space.m).frame(minHeight: 44)
                    }
                    .disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("addTaskButton")
                }
                .padding(DesignSystem.Space.l)

                Picker("Filter", selection: $filter) {
                    ForEach(Filter.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, DesignSystem.Space.l)
                .accessibilityIdentifier("taskFilterPicker")

                if filteredTasks.isEmpty {
                    Spacer()
                    DesignSystem.emptyState(
                        title: "No tasks here",
                        subtitle: filter == .all ? "Add your first task above." : "Nothing in this filter yet.",
                        ctaText: "Got it",
                        onCta: { dismiss() }
                    )
                    .accessibilityIdentifier("emptyTasksState")
                    Spacer()
                } else {
                    List {
                        ForEach(filteredTasks) { task in
                            // Done-ness is shown by the checkmark shape and the
                            // strikethrough, not by colour.
                            Button(action: { toggleComplete(task) }) {
                                HStack(spacing: DesignSystem.Space.m) {
                                    Image(systemName: task.completedAt != nil ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 20))
                                        .foregroundStyle(task.completedAt != nil ? Color.white : DesignSystem.textMuted2)
                                    Text(task.title)
                                        .font(.system(size: 15))
                                        .foregroundStyle(task.completedAt != nil ? DesignSystem.textMuted2 : .white)
                                        .strikethrough(task.completedAt != nil)
                                }
                                .padding(.vertical, DesignSystem.Space.xs)
                            }
                            .listRowBackground(DesignSystem.bgCanvas)
                            .listRowSeparatorTint(DesignSystem.borderCard)
                            .accessibilityIdentifier("taskRow_\(task.id)")
                            .swipeActions {
                                Button(role: .destructive) { removeTask(task) } label: {
                                    Label("Delete", systemImage: "trash")
                                }.tint(Color(hex: 0xE53935))
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .accessibilityIdentifier("tasksList")
                }
            }
            .visionScreen()
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear(perform: refresh)
    }

    private func refresh() {
        tasks = (try? taskStore.list()) ?? []
    }

    private func addTask() {
        let trimmed = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try? taskStore.add(title: trimmed)
        newTaskTitle = ""
        refresh()
    }

    private func toggleComplete(_ task: ProductivityTask) {
        guard task.completedAt == nil else { return }
        let completedForReal = (try? taskStore.complete(id: task.id)).flatMap { $0 } != nil
        if completedForReal {
            RewardEngine(store: rewardStore).awardIfEligible(type: .taskCompleted, note: "Completed \"\(task.title)\"")
        }
        refresh()
    }

    private func removeTask(_ task: ProductivityTask) {
        try? taskStore.remove(id: task.id)
        refresh()
    }
}
