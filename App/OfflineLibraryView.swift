import SwiftUI
import VisionCore

/// Real offline-saved-pages library — port of OfflineLibraryActivity.kt's
/// core list/open/delete surface, plus the per-item category reassignment
/// `OfflineAdapter.kt` wires to a `PopupMenu` (here a native SwiftUI `Menu`) —
/// this is what lets a real item land in the "education" category the Study
/// Material hub's Review tab reads. Recommendations are a disclosed scope trim
/// for this phase — see README.
///
/// Every item here is, by definition, stored on this device, so the screen
/// says that once in a caption rather than stamping each row with a badge. Rows
/// show the site's real favicon, title, domain, size and when it was saved.
/// The toolbar Done button exists because this sheet previously had no way
/// back out except tapping a row.
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
                        title: "No offline content yet",
                        subtitle: "Save a page for offline access, right from the browser's own menu.",
                        ctaText: "Got it",
                        onCta: { dismiss() }
                    )
                    .accessibilityIdentifier("emptyOfflineState")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Saved on this device — these pages open without a connection.")
                            .font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                            .padding(.horizontal, DesignSystem.Space.l).padding(.vertical, DesignSystem.Space.s)
                            .accessibilityIdentifier("offlineAvailabilityCaption")
                        List {
                            ForEach(items) { item in
                                row(for: item)
                                    .listRowBackground(DesignSystem.bgCanvas)
                                    .listRowSeparatorTint(DesignSystem.borderCard)
                                    .listRowInsets(EdgeInsets(top: DesignSystem.Space.m, leading: DesignSystem.Space.l, bottom: DesignSystem.Space.m, trailing: DesignSystem.Space.l))
                                    .swipeActions {
                                        Button(role: .destructive) { delete(item) } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .accessibilityIdentifier("offlineList")
                    }
                }
            }
            .navigationTitle("Offline Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .visionScreen()
        }
        .onAppear(perform: refresh)
    }

    @ViewBuilder
    private func row(for item: OfflineItem) -> some View {
        let host = FaviconCache.host(from: item.url) ?? item.url
        HStack(spacing: DesignSystem.Space.m) {
            Button(action: { open(item) }) {
                HStack(spacing: DesignSystem.Space.m) {
                    FaviconView(host: host, size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 15, weight: .medium)).foregroundStyle(.white)
                            .lineLimit(1)
                        Text("\(host) · \(ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file)) · Saved \(HistoryGrouping.dateTimeLabel(for: item.savedAt))")
                            .font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("offlineRow_\(item.id)")

            Menu {
                ForEach(offlineCategories, id: \.self) { category in
                    Button(category.capitalized) { reassignCategory(item, to: category) }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(item.category.capitalized).font(.system(size: 12))
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(DesignSystem.textMuted2)
            }
            .accessibilityIdentifier("offlineCategory_\(item.id)")
        }
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
