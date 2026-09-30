import SwiftUI

/// Minimal real New Tab page for Phase 1 — a real bookmarks row sourced
/// from BookmarkStore. No fake shortcuts or widgets yet (those land in a
/// later phase, matching vision-android's own Phase 28 New Tab redesign) —
/// this is deliberately smaller than either existing app's New Tab page
/// right now, not a hidden placeholder.
struct NewTabView: View {
    @ObservedObject var bookmarkStore: BookmarkStore
    let onNavigate: (String) -> Void

    @State private var bookmarks: [Bookmark] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DesignSystem.sectionLabel("Bookmarks")

                if bookmarks.isEmpty {
                    DesignSystem.emptyState(
                        emoji: "🔖",
                        title: "No bookmarks yet",
                        subtitle: "Tap the star in the address bar to save a page.",
                        ctaText: "Got it",
                        onCta: {}
                    )
                } else {
                    DesignSystem.card {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(bookmarks) { bookmark in
                                Button(action: { onNavigate(bookmark.url) }) {
                                    DesignSystem.statRow(emoji: "🔖", label: bookmark.title, value: "")
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(DesignSystem.bgCanvas.ignoresSafeArea())
        .onAppear(perform: refresh)
    }

    private func refresh() {
        bookmarks = (try? bookmarkStore.list()) ?? []
    }
}
