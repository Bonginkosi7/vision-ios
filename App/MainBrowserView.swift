import SwiftUI
import VisionCore

/// SwiftUI root of the browser — direct equivalent of MainActivity.kt:
/// address bar, back/forward, tab count, bookmark toggle, a secondary
/// toolbar for History/Downloads/Offline Library/Save Offline/New Private
/// Tab, and the active tab's content (either the shared New Tab page or its
/// real WKWebView). Focus Mode, permissions, and the overflow menu are
/// explicitly deferred to later phases (see vision-ios/README.md).
struct MainBrowserView: View {
    @StateObject private var tabManager = TabManager()
    @StateObject private var bookmarkStore = BookmarkStore()
    @StateObject private var historyStore = HistoryStore()
    @StateObject private var downloadStore = DownloadStore()
    @StateObject private var offlineStore = OfflineStore()
    @StateObject private var taskStore = TaskStore()
    @StateObject private var wellbeingStore = WellbeingStore()
    @StateObject private var focusStore = FocusStore()
    @ObservedObject private var focusManager = FocusManager.shared

    @State private var addressText: String = ""
    @State private var isBookmarked: Bool = false
    @State private var showHistory = false
    @State private var showDownloads = false
    @State private var showOfflineLibrary = false
    @State private var showSettings = false
    @State private var showRewrite = false
    @State private var showFocus = false
    @State private var showTasks = false
    @State private var showAdvisor = false
    @State private var saveOfflineStatus: String?

    var body: some View {
        VStack(spacing: 0) {
            addressBar
            Rectangle().fill(DesignSystem.borderCard).frame(height: 1)
            secondaryToolbar
            Rectangle().fill(DesignSystem.borderCard).frame(height: 1)
            content
        }
        .background(DesignSystem.bgCanvas.ignoresSafeArea())
        .onAppear {
            if tabManager.tabs.isEmpty {
                tabManager.createTab(url: nil)
            }
            // Startup hygiene matching Android's own FocusManager wiring:
            // a session row left open by a process that died mid-session
            // has no in-memory timer left to honor it, so it's closed as
            // data hygiene rather than left permanently dangling.
            try? focusStore.closeDanglingSessions()
            if let domains = try? focusStore.listBlockedDomains() {
                focusManager.setBlockedDomains(domains)
            }
        }
        .onChange(of: tabManager.activeTabIndex) { _ in syncAddressBar() }
        .sheet(isPresented: $showHistory) {
            HistoryView(historyStore: historyStore) { url in
                tabManager.navigateActiveTab(to: url)
            }
        }
        .sheet(isPresented: $showDownloads) {
            DownloadsView(downloadStore: downloadStore)
        }
        .sheet(isPresented: $showOfflineLibrary) {
            OfflineLibraryView(offlineStore: offlineStore) { fileURL in
                tabManager.openOfflineFile(fileURL)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showRewrite) {
            RewriteView()
        }
        .sheet(isPresented: $showFocus) {
            FocusView(focusStore: focusStore, focusManager: focusManager)
        }
        .sheet(isPresented: $showTasks) {
            TasksView(taskStore: taskStore)
        }
        .sheet(isPresented: $showAdvisor) {
            AdvisorView(wellbeingStore: wellbeingStore)
        }
    }

    @ViewBuilder
    private var addressBar: some View {
        HStack(spacing: 8) {
            Button(action: goBack) {
                Image(systemName: "chevron.left")
            }
            .disabled(!(tabManager.activeTab?.webView.canGoBack ?? false))
            .accessibilityIdentifier("backButton")

            Button(action: goForward) {
                Image(systemName: "chevron.right")
            }
            .disabled(!(tabManager.activeTab?.webView.canGoForward ?? false))
            .accessibilityIdentifier("forwardButton")

            TextField("Search or enter address", text: $addressText, onCommit: navigateFromAddressBar)
                .textFieldStyle(.plain)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(DesignSystem.bgCard))
                .accessibilityIdentifier("addressBarField")

            Button(action: toggleBookmark) {
                Image(systemName: isBookmarked ? "star.fill" : "star")
            }
            .accessibilityIdentifier("bookmarkButton")
            .accessibilityLabel(isBookmarked ? "Remove bookmark" : "Add bookmark")

            Text("\(tabManager.tabs.count)")
                .font(.system(size: 12, weight: .bold))
                .frame(width: 24, height: 24)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(DesignSystem.borderCard, lineWidth: 1))
                .accessibilityIdentifier("tabCountLabel")
        }
        .foregroundStyle(.white)
        .padding(8)
    }

    @ViewBuilder
    private var secondaryToolbar: some View {
        HStack(spacing: 20) {
            Button(action: { showHistory = true }) {
                Image(systemName: "clock")
            }
            .accessibilityIdentifier("historyButton")

            Button(action: { showDownloads = true }) {
                Image(systemName: "arrow.down.circle")
            }
            .accessibilityIdentifier("downloadsButton")

            Button(action: { showOfflineLibrary = true }) {
                Image(systemName: "icloud.and.arrow.down")
            }
            .accessibilityIdentifier("offlineLibraryButton")

            Button(action: saveActiveTabOffline) {
                Image(systemName: "square.and.arrow.down")
            }
            .disabled(tabManager.activeTab?.isNewTab ?? true)
            .accessibilityIdentifier("saveOfflineButton")

            Button(action: { showFocus = true }) {
                Image(systemName: "timer")
            }
            .accessibilityIdentifier("focusButton")

            Button(action: { showTasks = true }) {
                Image(systemName: "checklist")
            }
            .accessibilityIdentifier("tasksButton")

            Button(action: { showAdvisor = true }) {
                Image(systemName: "sparkles")
            }
            .accessibilityIdentifier("advisorButton")

            Spacer()

            if focusManager.activeSession != nil {
                Text("Focus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DesignSystem.visionPurple)
                    .accessibilityIdentifier("focusActiveIndicator")
            }

            if tabManager.activeTab?.isPrivate == true {
                Text("Private")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DesignSystem.visionBlue)
                    .accessibilityIdentifier("privateIndicator")
            }

            Button(action: { tabManager.createTab(url: nil, isPrivate: true) }) {
                Image(systemName: "eyeglasses")
            }
            .accessibilityIdentifier("newPrivateTabButton")

            Button(action: { showRewrite = true }) {
                Image(systemName: "pencil.and.outline")
            }
            .accessibilityIdentifier("rewriteButton")

            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape")
            }
            .accessibilityIdentifier("settingsButton")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .alert(
            "Save for Offline",
            isPresented: Binding(get: { saveOfflineStatus != nil }, set: { if !$0 { saveOfflineStatus = nil } })
        ) {
            Button("OK") { saveOfflineStatus = nil }
        } message: {
            Text(saveOfflineStatus ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        if let tab = tabManager.activeTab {
            // A real bug caught live in CI: reading `tab.isNewTab`/`tab.url`
            // off a plain local `let tab` here does NOT establish SwiftUI
            // observation of BrowserTab's own @Published properties — only
            // @StateObject/@ObservedObject-wrapped properties declared on a
            // View struct get that tracking. Without ActiveTabContent
            // wrapping `tab` in its own @ObservedObject, this view never
            // re-rendered when navigation flipped isNewTab to false, so the
            // WKWebView never appeared and the address bar never updated —
            // caught by a real UI test timing out waiting for real
            // navigation to reflect on screen, not spotted by reading the
            // code.
            ActiveTabContent(
                tab: tab,
                bookmarkStore: bookmarkStore,
                historyStore: historyStore,
                downloadStore: downloadStore,
                wellbeingStore: wellbeingStore
            ) { destination in
                tabManager.navigateActiveTab(to: destination)
            }
            .onReceive(tab.$url) { _ in syncAddressBar() }
            .onReceive(tab.$isNewTab) { _ in refreshBookmarkState() }
        } else {
            ProgressView().tint(.white)
        }
    }

    private func navigateFromAddressBar() {
        guard !addressText.isEmpty else { return }
        let destination = AddressResolver.resolveDestination(addressText, searchEngineUrl: AppSettings.searchEngine.queryUrl)
        tabManager.navigateActiveTab(to: destination)
        // Deliberately no synchronous syncAddressBar() call here — tab.url
        // hasn't been updated yet at this point (WKWebView.load() is async;
        // the real value only lands once the WKNavigationDelegate's
        // didCommit/didFinish callbacks fire), and calling it now would
        // just overwrite what the user typed with the tab's still-stale
        // empty url. The .onReceive(tab.$url) subscription above is what
        // correctly syncs the address bar once real navigation happens.
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

    private func saveActiveTabOffline() {
        guard let tab = tabManager.activeTab else { return }
        OfflineSaver.save(tab: tab, store: offlineStore) { result in
            switch result {
            case .success(let item):
                saveOfflineStatus = "Saved \"\(item.title)\" for offline (\(ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file)))."
            case .failure:
                saveOfflineStatus = "Couldn't save this page for offline right now."
            }
        }
    }
}

/// Wraps the active tab as a real @ObservedObject so SwiftUI actually
/// observes BrowserTab's own @Published isNewTab/url changes, instead of
/// silently missing them the way reading a plain local `let tab` inside a
/// parent view's body does.
private struct ActiveTabContent: View {
    @ObservedObject var tab: BrowserTab
    let bookmarkStore: BookmarkStore
    let historyStore: HistoryStore
    let downloadStore: DownloadStore
    let wellbeingStore: WellbeingStore
    let onNavigate: (String) -> Void

    var body: some View {
        if tab.isNewTab {
            NewTabView(bookmarkStore: bookmarkStore, onNavigate: onNavigate)
        } else {
            WebViewRepresentable(tab: tab, historyStore: historyStore, downloadStore: downloadStore, wellbeingStore: wellbeingStore)
        }
    }
}
