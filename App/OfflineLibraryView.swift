import SwiftUI

/// Real offline-saved-pages library — port of OfflineLibraryActivity.kt's
/// core list/open/delete surface, plus the real per-item category
/// reassignment `OfflineAdapter.kt` wires to a `PopupMenu` (here, a
/// native SwiftUI `Menu`) — this is what lets a real item ever land in
/// the "education" category the Study Material hub's Review tab reads.
/// Recommendations ("you might want this offline") are a disclosed
/// scope trim for this phase — see README.
///
/// Also fixed here: a real, pre-existing gap versus every sibling sheet
/// in this app — there was no "Done" button, so a user who opened this
/// just to browse/reassign categories (not to open a file) had no way
/// back out except tapping a row. Added the same toolbar Done every
/// other screen already has.
struct OfflineLibraryView: View {
    @ObservedObject var offlineStore: OfflineStore
    let onOpen: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var items: [OfflineItem] = []

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    DesignSystem.emptyState(
                        emoji: "☁️",
                        title: "No offline content yet",
                        subtitle: "Save a page for offline access, right from the browser's own menu.",
                        ctaText: "Got it",
                        onCta: { dismiss() }
                    )
                    .accessibilityIdentifier("emptyOfflineState")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DesignSystem.bgCanvas)
                } else {
                    List {
                        ForEach(items) { item in
                            HStack {
                                Button(action: { open(item) }) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title).foregroundStyle(.white).lineLimit(1)
                                        Text(ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file))
                                            .font(.caption).foregroundStyle(DesignSystem.textMuted2)
                                    }
                                }
                                .accessibilityIdentifier("offlineRow_\(item.id)")
                                Spacer()
                                Menu {
                                    ForEach(offlineCategories, id: \.self) { category in
                                        Button(category.capitalized) { reassignCategory(item, to: category) }
                                    }
                                } label: {
                                    Text(item.category.capitalized)
                                        .font(.caption).foregroundStyle(DesignSystem.textMuted2)
                                }
                                .accessibilityIdentifier("offlineCategory_\(item.id)")
                            }
                            .swipeActions {
                                Button(role: .destructive) { delete(item) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .accessibilityIdentifier("offlineList")
                }
            }
            .navigationTitle("Offline Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear(perform: refresh)
    }

    private func refresh() {
        items = (try? offlineStore.list()) ?? []
    }

    private func open(_ item: OfflineItem) {
        onOpen(URL(fileURLWithPath: item.contentPath))
        dismiss()
    }

    private func delete(_ item: OfflineItem) {
        try? FileManager.default.removeItem(atPath: item.contentPath)
        try? offlineStore.remove(id: item.id)
        refresh()
    }

    private func reassignCategory(_ item: OfflineItem, to category: String) {
        try? offlineStore.updateCategory(id: item.id, category: category)
        refresh()
    }
}
