import SwiftUI

/// Real personal task list — port of TasksActivity.kt. Binary open/
/// completed only, no fabricated "in progress" state (matches the real
/// Android/desktop data model); completion is one-way, enforced by
/// TaskStore.complete's own "was this actually still open" guard — a
/// completed task can't be tapped back to pending here.
struct TasksView: View {
    @ObservedObject var taskStore: TaskStore
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
                HStack {
                    TextField("Add a task", text: $newTaskTitle, onCommit: addTask)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(DesignSystem.bgCard))
                        .foregroundStyle(.white)
                        .accessibilityIdentifier("newTaskField")
                    Button(action: addTask) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("addTaskButton")
                }
                .padding(16)

                Picker("Filter", selection: $filter) {
                    ForEach(Filter.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .accessibilityIdentifier("taskFilterPicker")

                if filteredTasks.isEmpty {
                    Spacer()
                    DesignSystem.emptyState(
                        emoji: "✅",
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
                            Button(action: { toggleComplete(task) }) {
                                HStack {
                                    Image(systemName: task.completedAt != nil ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(task.completedAt != nil ? DesignSystem.statusSuccess : DesignSystem.textMuted2)
                                    Text(task.title)
                                        .foregroundStyle(.white)
                                        .strikethrough(task.completedAt != nil)
                                }
                            }
                            .accessibilityIdentifier("taskRow_\(task.id)")
                            .swipeActions {
                                Button(role: .destructive) { removeTask(task) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .accessibilityIdentifier("tasksList")
                }
            }
            .background(DesignSystem.bgCanvas.ignoresSafeArea())
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
        try? taskStore.complete(id: task.id)
        refresh()
    }

    private func removeTask(_ task: ProductivityTask) {
        try? taskStore.remove(id: task.id)
        refresh()
    }
}
