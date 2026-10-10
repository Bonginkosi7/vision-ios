import SwiftUI

/// Real multi-tab switcher — port of `MainActivity.kt`'s own
/// `showTabsDialog()`/`TabsAdapter`/`dialog_tabs.xml`: a real list of
/// every currently open tab, tap to switch, swipe to close, a real "New
/// Tab" action from within the switcher itself.
///
/// Found as the single most severe gap during a cross-source sweep:
/// `TabManager.switchToTab`/`closeTab` were already real, fully working,
/// already-tested methods (the pure index math behind `closeTab` has
/// its own `TabIndexing` test suite) — but nothing in the UI layer ever
/// called either one. The tab-count badge in the toolbar was a plain,
/// inert `Text`, so opening a second tab left the first permanently
/// unreachable: a core browser primitive silently non-functional behind
/// a button that looked real but did nothing.
struct TabSwitcherView: View {
    @ObservedObject var tabManager: TabManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(tabManager.tabs.enumerated()), id: \.element.id) { index, tab in
                    TabRow(tab: tab, isActive: index == tabManager.activeTabIndex) {
                        tabManager.switchToTab(index)
                        dismiss()
                    }
                    .accessibilityIdentifier("tabRow_\(tab.id)")
                    .listRowBackground(DesignSystem.bgCanvas)
                    .listRowSeparatorTint(DesignSystem.borderCard)
                    .swipeActions {
                        Button(role: .destructive) {
                            tabManager.closeTab(tab)
                        } label: {
                            Label("Close", systemImage: "xmark")
                        }
                        .accessibilityIdentifier("btnCloseTab_\(tab.id)")
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .accessibilityIdentifier("tabsList")
            .visionScreen()
            .navigationTitle("Tabs")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        tabManager.createTab(url: nil)
                        dismiss()
                    }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("btnNewTabFromSwitcher")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct TabRow: View {
    @ObservedObject var tab: BrowserTab
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tab.isNewTab ? "New Tab" : (tab.title.isEmpty ? tab.url : tab.title))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white).lineLimit(1)
                    if !tab.isNewTab {
                        Text(FaviconCache.host(from: tab.url) ?? tab.url)
                            .font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2).lineLimit(1)
                    }
                }
                Spacer()
                if tab.isPrivate {
                    Text("Private").font(.system(size: 12, weight: .semibold)).foregroundStyle(DesignSystem.textMuted2)
                }
                if isActive {
                    Image(systemName: "checkmark").foregroundStyle(.white)
                        .accessibilityIdentifier("activeTabCheckmark_\(tab.id)")
                }
            }
        }
    }
}
