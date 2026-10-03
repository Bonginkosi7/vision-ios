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
                    // Android's emptyBookmarksText (activity_bookmarks.xml) is a single
                    // plain, centered, 32dp-padded, 0.6-alpha TextView with one line of
                    // copy — no emoji, no title/subtitle split, no CTA button. This
                    // screen (BookmarksActivity.kt) never touches the componentized
                    // DesignSystem.kt, so DesignSystem.emptyState (which always renders
                    // an illustration + CTA) doesn't belong here; match the plain text.
                    Text("No bookmarks yet — tap the star on any page to save it.")
                        .multilineTextAlignment(.center)
                        .opacity(0.6)
                        .padding(32)
                        .accessibilityIdentifier("emptyBookmarksListState")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(bookmarks) { bookmark in
                            HStack(spacing: 12) {
                                // The real bug this fixes (hit several times before in this
                                // codebase): applying .accessibilityIdentifier to a container
                                // with more than one interactive child — here, this open
                                // button AND the trailing delete button — doesn't tag one
                                // merged element, it pushes the SAME identifier onto every
                                // child independently. A real CI run confirmed this exactly:
                                // app.buttons["bookmarksListRow_<url>"] matched BOTH buttons.
                                // The identifier belongs on the specific button this screen's
                                // own UI test actually queries, not the row container.
                                Button(action: { onOpen(bookmark.url); dismiss() }) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        // Android's bookmarkTitle is textStyle="bold" 15sp.
                                        Text(bookmark.title)
                                            .font(.system(size: 15, weight: .bold))
                                            .lineLimit(1)
                                        // Android's bookmarkUrl is 12sp at alpha 0.65 of the
                                        // default (theme-adaptive) text color.
                                        Text(bookmark.url)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("bookmarksListRow_\(bookmark.url)")
                                Spacer(minLength: 8)
                                // Android has no swipe-to-delete here: btnDeleteBookmark is an
                                // always-visible 40dp ImageButton (ic_menu_delete) at the row's
                                // trailing end, a separate tap target from the row body.
                                Button(action: { delete(bookmark) }) {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Delete")
                            }
                            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 8))
                            // A second real CI run found a second, different
                            // half of the same accessibility-merging class of
                            // bug fixed above: without this, SwiftUI's default
                            // behavior re-merges a row's multiple interactive
                            // children into one accessibility element for
                            // VoiceOver — which swallowed the trailing delete
                            // button's own identity entirely (app.buttons["Delete"]
                            // stopped resolving to anything after the open
                            // button gained its own identifier). Confirmed via
                            // the real captured log: the delete button simply
                            // never appeared after an otherwise-successful
                            // swipe. `.contain` keeps every child independently
                            // accessible — same fix New Tab's own bookmarks row
                            // already needed for the identical reason.
                            .accessibilityElement(children: .contain)
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
