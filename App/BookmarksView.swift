import SwiftUI
import UniformTypeIdentifiers
import VisionCore

/// Real saved bookmarks list — port of `BookmarksActivity.kt`: list, tap to
/// open, per-entry delete. Each row shows the site's real favicon (cached
/// on-device, a grey globe when none was captured), the page title and the
/// domain and the time it was saved. Like History, bookmarks sit under day
/// headings (Today, Yesterday, …) and a row of quick ranges (All / Today /
/// Yesterday / Last 7 days / Last 30 days) narrows the list. There are no
/// folders to preserve on iOS.
///
/// Accessibility structure below is deliberate and CI-proven, not incidental:
/// - the open button and the delete button are siblings, each with its own
///   URL-scoped identifier (putting one identifier on the row container pushed
///   it onto BOTH children and broke queries);
/// - `.accessibilityElement(children: .contain)` stops SwiftUI merging the two
///   buttons into one element for VoiceOver, which had swallowed the delete
///   button's identity.
struct BookmarksView: View {
    @ObservedObject var bookmarkStore: BookmarkStore
    let onOpen: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var bookmarks: [Bookmark] = []
    @State private var showImporter = false
    @State private var importMessage: String?
    @State private var range: BookmarkRange = .all

    private var groups: [DatedGroup<Bookmark>] {
        DayGrouping.group(bookmarks, range: range, dateOf: \.createdAt)
    }

    var body: some View {
        NavigationStack {
            Group {
                if bookmarks.isEmpty {
                    emptyText(BookmarkRange.all.emptyText)
                } else {
                    VStack(spacing: 0) {
                        rangeChips
                        if groups.isEmpty {
                            emptyText(range.emptyText)
                        } else {
                            List {
                                ForEach(groups, id: \.label) { group in
                                    Section {
                                        ForEach(group.items) { bookmark in
                                            row(for: bookmark)
                                                .listRowBackground(DesignSystem.bgCanvas)
                                                .listRowSeparatorTint(DesignSystem.borderCard)
                                                .listRowInsets(EdgeInsets(top: DesignSystem.Space.m, leading: DesignSystem.Space.l, bottom: DesignSystem.Space.m, trailing: DesignSystem.Space.s))
                                                .accessibilityElement(children: .contain)
                                        }
                                    } header: {
                                        DesignSystem.sectionLabel("\(group.label) · \(group.items.count)")
                                            .textCase(nil)
                                            .listRowInsets(EdgeInsets(top: DesignSystem.Space.m, leading: 0, bottom: DesignSystem.Space.xs, trailing: 0))
                                    }
                                    .listRowBackground(DesignSystem.bgCanvas)
                                }
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                            .accessibilityIdentifier("bookmarksList")
                        }
                    }
                }
            }
            .navigationTitle("Bookmarks")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Import") { showImporter = true }
                        .accessibilityIdentifier("bookmarksImportButton")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.html]) { result in
                importBookmarks(from: result)
            }
            .alert("Import bookmarks", isPresented: Binding(get: { importMessage != nil }, set: { if !$0 { importMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importMessage ?? "")
            }
            .visionScreen()
        }
        .onAppear {
            refresh()
            #if DEBUG
            // UI tests can't drive the system file picker, so they ask for a small built-in bookmarks file instead.
            if ProcessInfo.processInfo.arguments.contains("-UITestImportBookmarksFixture") {
                applyImport(html: "<DL><DT><A HREF=\"https://import-test.example.com/\">Imported One</A><DT><A HREF=\"javascript:alert(1)\">Bad</A></DL>")
            }
            #endif
        }
    }

    /// Adds the web addresses from a bookmarks.html file exported by another browser (Chrome, Safari, Firefox, Edge…).
    private func importBookmarks(from result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let opened = url.startAccessingSecurityScopedResource()
        defer { if opened { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), data.count <= 25 * 1024 * 1024,
              let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        else {
            importMessage = "That file couldn't be read."
            return
        }
        applyImport(html: html)
    }

    private func applyImport(html: String) {
        let plan = BookmarkImport.plan(BookmarkImport.parse(html: html)) { address in
            ((try? bookmarkStore.isBookmarked(url: address)) ?? nil) != nil
        }
        for item in plan.toAdd { _ = try? bookmarkStore.add(title: item.title, url: item.url) }
        importMessage = BookmarkImport.describe(plan.summary)
        refresh()
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundStyle(DesignSystem.textMuted2)
            .multilineTextAlignment(.center)
            .padding(DesignSystem.Space.xxl)
            .accessibilityIdentifier("emptyBookmarksListState")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var rangeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Space.s) {
                ForEach(BookmarkRange.allCases, id: \.self) { option in
                    let selected = option == range
                    Button(action: { range = option }) {
                        Text(option.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(selected ? Color.black : Color.white)
                            .padding(.horizontal, DesignSystem.Space.m).frame(minHeight: 34)
                            .background(Capsule().fill(selected ? Color.white : DesignSystem.bgCard))
                            .overlay(Capsule().stroke(DesignSystem.borderCard, lineWidth: selected ? 0 : 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .accessibilityIdentifier("bookmarkRange_\(option.rawValue)")
                }
            }
            .padding(.horizontal, DesignSystem.Space.l)
            .padding(.vertical, DesignSystem.Space.s)
        }
    }

    @ViewBuilder
    private func row(for bookmark: Bookmark) -> some View {
        let host = FaviconCache.host(from: bookmark.url) ?? bookmark.url
        HStack(spacing: DesignSystem.Space.m) {
            Button(action: { onOpen(bookmark.url); dismiss() }) {
                HStack(spacing: DesignSystem.Space.m) {
                    FaviconView(host: host, size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bookmark.title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text("\(host) · \(HistoryGrouping.timeLabel(for: bookmark.createdAt))")
                            .font(.system(size: 12))
                            .foregroundStyle(DesignSystem.textMuted2)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("bookmarksListRow_\(bookmark.url)")

            // Always visible, a separate target from the row body (as on
            // Android). Identifier is URL-scoped because every row's button
            // shares the label "Delete" and the suite shares one database.
            Button(action: { delete(bookmark) }) {
                Image(systemName: "trash")
                    .font(.system(size: 15))
                    .foregroundStyle(DesignSystem.textMuted2)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("btnDeleteBookmark_\(bookmark.url)")
            .accessibilityLabel("Delete")
        }
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
