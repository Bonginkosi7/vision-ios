import SwiftUI

/// Real browsing history — port of HistoryActivity.kt: search, list,
/// per-entry delete, clear all, tap to open. A plain SwiftUI `List` is used
/// here (not a custom VStack-of-Buttons like NewTabView's bookmarks row)
/// specifically because List/ForEach rows stay independently accessible by
/// default — the accessibility-merging issue Phase 1 hit doesn't apply here.
struct HistoryView: View {
    @ObservedObject var historyStore: HistoryStore
    let onOpen: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    @State private var entries: [HistoryEntry] = []
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    DesignSystem.emptyState(
                        emoji: "🕘",
                        title: "No history yet",
                        subtitle: "Pages you visit will show up here.",
                        ctaText: "Got it",
                        onCta: { dismiss() }
                    )
                    .accessibilityIdentifier("emptyHistoryState")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DesignSystem.bgCanvas)
                } else {
                    List {
                        ForEach(entries) { entry in
                            Button(action: { onOpen(entry.url); dismiss() }) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.title).foregroundStyle(.white).lineLimit(1)
                                    Text(entry.url).font(.caption).foregroundStyle(DesignSystem.textMuted2).lineLimit(1)
                                }
                            }
                            .accessibilityIdentifier("historyRow_\(entry.id)")
                            .swipeActions {
                                Button(role: .destructive) {
                                    delete(entry)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .accessibilityIdentifier("historyList")
                }
            }
            .searchable(text: $query, prompt: "Search history")
            .onChange(of: query) { _ in refresh() }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") { showClearConfirm = true }
                        .accessibilityIdentifier("clearHistoryButton")
                        .disabled(entries.isEmpty)
                }
            }
            .confirmationDialog("Clear all history?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Clear History", role: .destructive) { clearAll() }
                Button("Cancel", role: .cancel) {}
            }
        }
        .onAppear(perform: refresh)
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
