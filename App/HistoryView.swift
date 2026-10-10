import SwiftUI
import VisionCore

/// Real browsing history — port of HistoryActivity.kt: search, list,
/// per-entry delete, clear all, tap to open.
///
/// Each visit shows the site's real favicon (from the on-device cache; a quiet
/// grey globe when none was captured), the page title, the domain and the
/// visit time, grouped under headings computed from the real timestamps
/// (`HistoryGrouping`: Today, Yesterday, Earlier this week, Last week, …).
///
/// A plain `List` keeps rows independently accessible. The open button and
/// the delete button are SIBLINGS, never nested — Android's row has the same
/// two independent targets — and each carries its own identifier.
struct HistoryView: View {
    @ObservedObject var historyStore: HistoryStore
    let onOpen: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    @State private var entries: [HistoryEntry] = []
    @State private var showClearConfirm = false

    private struct HistorySection: Identifiable {
        let id: String
        let label: String
        let items: [HistoryEntry]
    }

    /// Contiguous runs under the same heading — valid because HistoryStore
    /// always returns entries newest first.
    private var sections: [HistorySection] {
        let now = Date()
        var result: [HistorySection] = []
        var currentLabel: String?
        var currentItems: [HistoryEntry] = []
        for entry in entries {
            let label = HistoryGrouping.sectionLabel(for: entry.visitedAt, now: now)
            if label != currentLabel {
                if let currentLabel {
                    result.append(HistorySection(id: currentItems.first?.id ?? currentLabel, label: currentLabel, items: currentItems))
                }
                currentLabel = label
                currentItems = [entry]
            } else {
                currentItems.append(entry)
            }
        }
        if let currentLabel {
            result.append(HistorySection(id: currentItems.first?.id ?? currentLabel, label: currentLabel, items: currentItems))
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    DesignSystem.emptyState(
                        title: query.isEmpty ? "No browsing history yet" : "No matches",
                        subtitle: query.isEmpty ? "Pages you visit will show up here." : "Nothing in your history matches that search.",
                        ctaText: "Got it",
                        onCta: { dismiss() }
                    )
                    .accessibilityIdentifier("emptyHistoryState")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(sections) { section in
                            Section {
                                ForEach(section.items) { entry in
                                    row(for: entry)
                                }
                            } header: {
                                DesignSystem.sectionLabel(section.label)
                                    .textCase(nil)
                                    .listRowInsets(EdgeInsets(top: DesignSystem.Space.m, leading: 0, bottom: DesignSystem.Space.xs, trailing: 0))
                            }
                            .listRowBackground(DesignSystem.bgCanvas)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .accessibilityIdentifier("historyList")
                }
            }
            .searchable(text: $query, prompt: "Search history")
            .onChange(of: query) { _ in refresh() }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear all") { showClearConfirm = true }
                        .accessibilityIdentifier("clearHistoryButton")
                        .disabled(entries.isEmpty)
                }
            }
            .confirmationDialog("Clear all", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Clear all", role: .destructive) { clearAll() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes all your browsing history. This can't be undone.")
            }
            .visionScreen()
        }
        .onAppear(perform: refresh)
    }

    @ViewBuilder
    private func row(for entry: HistoryEntry) -> some View {
        let host = FaviconCache.host(from: entry.url) ?? entry.url
        HStack(spacing: DesignSystem.Space.m) {
            Button(action: { onOpen(entry.url); dismiss() }) {
                HStack(spacing: DesignSystem.Space.m) {
                    FaviconView(host: host, size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text("\(host) · \(HistoryGrouping.timeLabel(for: entry.visitedAt))")
                            .font(.system(size: 12))
                            .foregroundStyle(DesignSystem.textMuted2)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("historyRow_\(entry.id)")

            Button(action: { delete(entry) }) {
                Image(systemName: "trash")
                    .font(.system(size: 15))
                    .foregroundStyle(DesignSystem.textMuted2)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("historyRowDelete_\(entry.id)")
        }
        .listRowSeparatorTint(DesignSystem.borderCard)
        .swipeActions {
            Button(role: .destructive) {
                delete(entry)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func refresh() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        entries = (try? (trimmed.isEmpty ? historyStore.list() : historyStore.search(trimmed))) ?? []
    }

    private func delete(_ entry: HistoryEntry) {
        try? historyStore.deleteEntry(id: entry.id)
        refresh()
    }

    private func clearAll() {
        try? historyStore.clear()
        refresh()
    }
}
