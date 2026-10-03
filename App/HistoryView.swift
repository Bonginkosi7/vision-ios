import SwiftUI

/// Real browsing history — port of HistoryActivity.kt: search, list,
/// per-entry delete, clear all, tap to open. A plain SwiftUI `List` is used
/// here (not a custom VStack-of-Buttons like NewTabView's bookmarks row)
/// specifically because List/ForEach rows stay independently accessible by
/// default — the accessibility-merging issue Phase 1 hit doesn't apply here.
///
/// Visually ported from Android's real History screen, not just its data
/// shape: Android groups rows under real date-section headers ("Today" /
/// "Yesterday" / "EEEE, d MMM yyyy" — HistoryGrouping.dayLabel) with a bold
/// sectionLabel-style header per group, and every row carries a
/// deterministic colored letter-avatar circle (HistoryAvatar.kt) — Android's
/// WebView has no per-page favicon callback, so that fallback is drawn for
/// every entry, not just some, and is reproduced verbatim here (same 8-color
/// palette, same hash) rather than reaching for FaviconLoader's
/// real-favicon-or-globe look, which is a different screen's honest fallback
/// for a different situation.
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

    /// Contiguous same-day runs, same construction as HistoryAdapter.submit's
    /// "if label != lastLabel, start a new header" loop — valid because
    /// entries always arrive sorted by visitedAt desc from HistoryStore.
    private var sections: [HistorySection] {
        var result: [HistorySection] = []
        var currentLabel: String?
        var currentItems: [HistoryEntry] = []
        for entry in entries {
            let label = dayLabel(for: entry.visitedAt)
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

    /// Direct port of HistoryGrouping.dayLabel(): Today / Yesterday / full weekday date.
    private func dayLabel(for date: Date) -> String {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfEntry = calendar.startOfDay(for: date)
        let diffDays = calendar.dateComponents([.day], from: startOfEntry, to: startOfToday).day ?? 0
        switch diffDays {
        case 0: return "Today"
        case 1: return "Yesterday"
        default:
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, d MMM yyyy"
            return formatter.string(from: date)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    DesignSystem.emptyState(
                        emoji: "🕘",
                        title: "No browsing history yet",
                        subtitle: "Pages you visit will show up here.",
                        ctaText: "Got it",
                        onCta: { dismiss() }
                    )
                    .accessibilityIdentifier("emptyHistoryState")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DesignSystem.bgCanvas)
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
                                    .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 4, trailing: 0))
                            }
                            .listRowBackground(DesignSystem.bgCanvas)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(DesignSystem.bgCanvas)
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
        }
        .onAppear(perform: refresh)
    }

    /// One row: avatar circle, bold title + muted url, trailing delete —
    /// matches item_history_entry.xml's historyAvatar / historyTitle /
    /// historyMeta / btnDeleteHistory layout (the open-button and the
    /// delete-button are kept as SIBLING buttons, not nested, since Android's
    /// own itemView click and btnDeleteHistory click are two independent
    /// listeners on the same row too).
    @ViewBuilder
    private func row(for entry: HistoryEntry) -> some View {
        HStack(spacing: 12) {
            Button(action: { onOpen(entry.url); dismiss() }) {
                HStack(spacing: 12) {
                    HistoryAvatarView(url: entry.url)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(entry.url)
                            .font(.caption)
                            .foregroundStyle(DesignSystem.textMuted2)
                            .lineLimit(1)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("historyRow_\(entry.id)")

            Spacer(minLength: 8)

            Button(action: { delete(entry) }) {
                Image(systemName: "trash")
                    .foregroundStyle(DesignSystem.textMuted2)
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

/// Deterministic colored letter-avatar — verbatim port of HistoryAvatar.kt's
/// forUrl()/hostnameOf(): same 8-color palette in the same order, same
/// `hash = hash * 31 + char` rolling hash, same "strip leading www." rule.
/// Never a generic system glyph, because Android's own fallback here isn't
/// a "loading" placeholder, it's the genuine, only rendering history ever
/// gets on that platform.
private struct HistoryAvatarView: View {
    let url: String

    private static let colors: [Color] = [
        Color(hex: 0x7B3FF2), Color(hex: 0x3B6FFF), Color(hex: 0x22E1FF), Color(hex: 0xFF6B6B),
        Color(hex: 0xF59E0B), Color(hex: 0x22C55E), Color(hex: 0xEC4899), Color(hex: 0x14B8A6),
    ]

    private var hostname: String {
        let host = URL(string: url)?.host ?? url
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    private var letter: String {
        hostname.first.map { String($0).uppercased() } ?? "?"
    }

    private var color: Color {
        var hash: Int32 = 0
        for scalar in hostname.unicodeScalars {
            hash = (hash &* 31 &+ Int32(truncatingIfNeeded: scalar.value)) & 0x7FFFFFFF
        }
        let index = Int(hash) % Self.colors.count
        return Self.colors[index]
    }

    var body: some View {
        Text(letter)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(Circle().fill(color))
    }
}
