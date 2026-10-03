import SwiftUI

/// Real saved bookmarks list — port of `BookmarksActivity.kt`: list, tap
/// to open, per-entry delete. New Tab already shows a bookmarks row for
/// quick access; this is the real, dedicated management screen Android's
/// own overflow menu reaches separately (`action_bookmarks`) — found as
/// a genuine, previously-undisclosed gap during a cross-source sweep
/// (`BookmarkStore.swift` already had everything this screen needs
/// since Phase 1, it just had no screen of its own yet).
struct BookmarksView: View {
    @ObservedObject var bookmarkStore: BookmarkStore
    let onOpen: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var bookmarks: [Bookmark] = []

    var body: some View {
        NavigationStack {
            Group {
                if bookmarks.isEmpty {
                    DesignSystem.emptyState(
                        emoji: "🔖",
                        title: "No bookmarks yet",
                        subtitle: "Tap the star in the address bar to save a page.",
                        ctaText: "Got it",
                        onCta: { dismiss() }
                    )
                    .accessibilityIdentifier("emptyBookmarksListState")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DesignSystem.bgCanvas)
                } else {
                    List {
                        ForEach(bookmarks) { bookmark in
                            Button(action: { onOpen(bookmark.url); dismiss() }) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(bookmark.title).foregroundStyle(.white).lineLimit(1)
                                    Text(bookmark.url).font(.caption).foregroundStyle(DesignSystem.textMuted2).lineLimit(1)
                                }
                            }
                            .accessibilityIdentifier("bookmarksListRow_\(bookmark.url)")
                            .swipeActions {
                                Button(role: .destructive) {
                                    delete(bookmark)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .accessibilityIdentifier("bookmarksList")
                }
            }
            .navigationTitle("Bookmarks")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear(perform: refresh)
    }

    private func refresh() {
        bookmarks = (try? bookmarkStore.list()) ?? []
    }

    private func delete(_ bookmark: Bookmark) {
        guard let id = bookmark.id else { return }
        try? bookmarkStore.remove(id: id)
        refresh()
    }
}
