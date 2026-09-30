import SwiftUI
import VisionCore

/// SwiftUI root of the browser — direct equivalent of MainActivity.kt:
/// address bar, back/forward, tab count, bookmark toggle, and the active
/// tab's content (either the shared New Tab page or its real WKWebView).
/// Focus Mode, downloads, permissions, and the overflow menu are explicitly
/// deferred to later phases (see vision-ios/README.md).
struct MainBrowserView: View {
    @StateObject private var tabManager = TabManager()
    @StateObject private var bookmarkStore = BookmarkStore()
    @State private var addressText: String = ""
    @State private var isBookmarked: Bool = false

    // Phase 1 hardcodes Google — a real Settings-backed search-engine
    // choice (matching VisionSettings.getSearchEngine on Android) is Phase
    // 3 scope, not invented early.
    private let searchEngineUrl = "https://www.google.com/search?q="

    var body: some View {
        VStack(spacing: 0) {
            addressBar
            Rectangle().fill(DesignSystem.borderCard).frame(height: 1)
            content
        }
        .background(DesignSystem.bgCanvas.ignoresSafeArea())
        .onAppear {
            if tabManager.tabs.isEmpty {
                tabManager.createTab(url: nil)
            }
        }
        .onChange(of: tabManager.activeTabIndex) { _ in syncAddressBar() }
    }

    @ViewBuilder
    private var addressBar: some View {
        HStack(spacing: 8) {
            Button(action: goBack) {
                Image(systemName: "chevron.left")
            }
            .disabled(!(tabManager.activeTab?.webView.canGoBack ?? false))

            Button(action: goForward) {
                Image(systemName: "chevron.right")
            }
            .disabled(!(tabManager.activeTab?.webView.canGoForward ?? false))

            TextField("Search or enter address", text: $addressText, onCommit: navigateFromAddressBar)
                .textFieldStyle(.plain)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(DesignSystem.bgCard))

            Button(action: toggleBookmark) {
                Image(systemName: isBookmarked ? "star.fill" : "star")
            }

            Text("\(tabManager.tabs.count)")
                .font(.system(size: 12, weight: .bold))
                .frame(width: 24, height: 24)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(DesignSystem.borderCard, lineWidth: 1))
        }
        .foregroundStyle(.white)
        .padding(8)
    }

    @ViewBuilder
    private var content: some View {
        if let tab = tabManager.activeTab {
            if tab.isNewTab {
                NewTabView(bookmarkStore: bookmarkStore) { destination in
                    tabManager.navigateActiveTab(to: destination)
                    syncAddressBar()
                }
            } else {
                WebViewRepresentable(tab: tab)
                    .onReceive(tab.$url) { _ in
                        syncAddressBar()
                    }
            }
        } else {
            ProgressView().tint(.white)
        }
    }

    private func navigateFromAddressBar() {
        guard !addressText.isEmpty else { return }
        let destination = AddressResolver.resolveDestination(addressText, searchEngineUrl: searchEngineUrl)
        tabManager.navigateActiveTab(to: destination)
        syncAddressBar()
    }

    private func goBack() { tabManager.activeTab?.webView.goBack() }
    private func goForward() { tabManager.activeTab?.webView.goForward() }

    private func syncAddressBar() {
        addressText = tabManager.activeTab?.url ?? ""
        refreshBookmarkState()
    }

    private func refreshBookmarkState() {
        guard let url = tabManager.activeTab?.url, !url.isEmpty else {
            isBookmarked = false
            return
        }
        isBookmarked = (try? bookmarkStore.isBookmarked(url: url)) != nil
    }

    private func toggleBookmark() {
        guard let tab = tabManager.activeTab, !tab.url.isEmpty else { return }
        do {
            if let existing = try bookmarkStore.isBookmarked(url: tab.url), let id = existing.id {
                try bookmarkStore.remove(id: id)
            } else {
                try bookmarkStore.add(title: tab.title.isEmpty ? tab.url : tab.title, url: tab.url)
            }
            refreshBookmarkState()
        } catch {
            // A failed bookmark write has no toast/alert wiring yet in
            // Phase 1 — isBookmarked simply doesn't flip, which is honest
            // (never claims success on a write that didn't happen) even
            // though it's not yet a great UX. Real error surfacing is a
            // later-phase concern, not invented here.
        }
    }
}
