import SwiftUI
import VisionCore

/// SwiftUI root of the browser — direct equivalent of MainActivity.kt: one
/// real toolbar row (back/forward/address bar/bookmark/tab count/overflow
/// menu) plus the active tab's content (either the shared New Tab page or
/// its real WKWebView).
///
/// Everything beyond back/forward/bookmark lives behind a single real
/// overflow menu button, matching Android's own showOverflowMenu()
/// architecture exactly — Android's whole toolbar is just Back/Forward/
/// address bar/Bookmark/tab-count plus one "⋮" button opening a popup with
/// every other action (History, Downloads, Focus Mode, Rewards, etc.).
/// iOS Phases 1–7 instead grew a second row of always-visible icon
/// buttons, which genuinely broke in CI once there were enough of them to
/// push "History" off the right edge of the screen — a real XCUITest
/// failure (`kAXErrorCannotComplete` scrolling to an off-screen button),
/// not a cosmetic one, caught the same way every other real bug in this
/// project has been: a CI run, not a guess. Fixed here by actually
/// matching the real source's navigation architecture (a single SwiftUI
/// `Menu`) instead of patching the symptom (e.g. wrapping the row in a
/// horizontal ScrollView), since the same overflow would only have
/// recurred as later phases (Flashcards, Exams, Redeem, Chat, ...) kept
/// adding more always-visible buttons.
/// Carries Ask VISION's real, order-independent-of-presentation state
/// into `.sheet(item:)` as one atomic value (query and
/// presented-or-not together) instead of two separate `@State` vars
/// that have to agree with each other — a real CI failure proved the
/// two-var version genuinely raced: the sheet could present with its
/// content closure still reading the old `initialQuery` value,
/// landing on the real session list instead of auto-asking.
private struct AskVisionRequest: Identifiable {
    let id = UUID()
    let query: String?
}

struct MainBrowserView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var tabManager = TabManager()
    @StateObject private var bookmarkStore = BookmarkStore()
    @StateObject private var historyStore = HistoryStore()
    @StateObject private var downloadStore = DownloadStore()
    @StateObject private var offlineStore = OfflineStore()
    @StateObject private var taskStore = TaskStore()
    @StateObject private var wellbeingStore = WellbeingStore()
    @StateObject private var focusStore = FocusStore()
    @StateObject private var rewardStore = RewardStore()
    @StateObject private var redemptionStore = RedemptionStore()
    @StateObject private var studyDocumentStore = StudyDocumentStore()
    @StateObject private var studyReviewStore = StudyReviewStore()
    @StateObject private var topicStore = TopicStore()
    @StateObject private var flashcardStore = FlashcardStore()
    @StateObject private var examStore = ExamStore()
    @StateObject private var tutorStore = TutorStore()
    @StateObject private var studyPlanStore = StudyPlanStore()
    @StateObject private var chatSessionStore = ChatSessionStore()
    @StateObject private var shortcutStore = ShortcutStore()
    @ObservedObject private var focusManager = FocusManager.shared

    private var performanceCalculator: PerformanceCalculator {
        PerformanceCalculator(topicStore: topicStore, flashcardStore: flashcardStore, examStore: examStore, studyDocumentStore: studyDocumentStore)
    }
    private var studySessionManager: StudySessionManager {
        StudySessionManager(studyPlanStore: studyPlanStore, performanceCalculator: performanceCalculator, topicStore: topicStore, rewardEngine: RewardEngine(store: rewardStore))
    }

    @State private var addressText: String = ""
    @State private var isBookmarked: Bool = false
    @State private var showHistory = false
    @State private var showTabSwitcher = false
    @State private var showBookmarksList = false
    @State private var showDownloads = false
    @State private var showOfflineLibrary = false
    @State private var showSettings = false
    @State private var showRewrite = false
    @State private var showFocus = false
    @State private var showTasks = false
    @State private var showAdvisor = false
    @State private var showRewards = false
    @State private var showRedeem = false
    @State private var showMaterials = false
    @State private var showStudyMaterial = false
    @State private var showFlashcards = false
    @State private var showExams = false
    @State private var showTutor = false
    @State private var showPerformance = false
    @State private var showStudyPlan = false
    @State private var showPaperReview = false
    @State private var showHelp = false
    @State private var askVisionRequest: AskVisionRequest?
    @State private var showVisionReady = false
    @State private var saveOfflineStatus: String?

    var body: some View {
        VStack(spacing: 0) {
            addressBar
            Rectangle().fill(DesignSystem.borderCard).frame(height: 1)
            content
        }
        .background(DesignSystem.bgCanvas.ignoresSafeArea())
        .overlay {
            // Real privacy for the real content, not just a label — the
            // iOS counterpart of PrivateBrowsingActivity.kt's own
            // `FLAG_SECURE` (blanks the system Recents thumbnail). iOS has
            // no API to block an in-app screenshot the way Android's flag
            // does — a genuine platform gap, not something this can close
            // — but hiding real content the instant the app leaves the
            // foreground closes the thumbnail half of it: covering a
            // private tab's page before the OS captures its own app-
            // switcher snapshot. Found missing entirely during a
            // cross-source design sweep.
            if scenePhase != .active && tabManager.activeTab?.isPrivate == true {
                DesignSystem.bgCanvas.ignoresSafeArea()
                    .overlay {
                        Text("Private").font(.system(size: 15, weight: .bold)).foregroundStyle(DesignSystem.visionBlue)
                    }
                    .accessibilityIdentifier("privateSessionCover")
            }
        }
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
            // Centralized here (not inside FocusView) to match
            // VisionApplication.kt's own single wiring point exactly: set
            // once at launch, so a session started and later ending while
            // FocusView isn't even open still gets persisted and still
            // earns its real reward. Only a session that genuinely ran its
            // full planned length (15+ min, MIN_FOCUS_MINUTES_FOR_REWARD)
            // without being stopped early is reward-eligible — starting
            // one and immediately stopping it can't be farmed for points.
            focusManager.onSessionEnd = { ended, completedNaturally in
                try? focusStore.endSession(id: ended.id, blockedAttempts: ended.blockedAttempts)
                if completedNaturally && ended.plannedMinutes >= 15 {
                    RewardEngine(store: rewardStore).awardIfEligible(
                        type: .focusSessionCompleted,
                        note: "Completed a \(ended.plannedMinutes)-minute Focus Session"
                    )
                }
            }
            seedMaterialsFixtureIfRequested()
        }
        .onChange(of: tabManager.activeTabIndex) { _ in syncAddressBar() }
        .sheet(isPresented: $showTabSwitcher) {
            TabSwitcherView(tabManager: tabManager)
        }
        .sheet(isPresented: $showHistory) {
            HistoryView(historyStore: historyStore) { url in
                tabManager.navigateActiveTab(to: url)
            }
        }
        .sheet(isPresented: $showBookmarksList) {
            BookmarksView(bookmarkStore: bookmarkStore) { url in
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
            SettingsView(historyStore: historyStore)
        }
        .sheet(isPresented: $showRewrite) {
            RewriteView()
        }
        .sheet(isPresented: $showFocus) {
            FocusView(focusStore: focusStore, focusManager: focusManager)
        }
        .sheet(isPresented: $showTasks) {
            TasksView(taskStore: taskStore, rewardStore: rewardStore)
        }
        .sheet(isPresented: $showAdvisor) {
            AdvisorView(wellbeingStore: wellbeingStore, rewardStore: rewardStore)
        }
        .sheet(isPresented: $showRewards) {
            RewardsView(rewardStore: rewardStore)
        }
        .sheet(isPresented: $showRedeem) {
            RedeemContainerView(redemptionStore: redemptionStore, rewardStore: rewardStore)
        }
        .sheet(isPresented: $showMaterials) {
            MaterialsView(studyDocumentStore: studyDocumentStore, topicStore: topicStore)
        }
        .sheet(isPresented: $showStudyMaterial) {
            StudyMaterialView(studyDocumentStore: studyDocumentStore, offlineStore: offlineStore, studyReviewStore: studyReviewStore) { url in
                tabManager.navigateActiveTab(to: url)
            }
        }
        .sheet(isPresented: $showFlashcards) {
            FlashcardsView(studyDocumentStore: studyDocumentStore, flashcardStore: flashcardStore, topicStore: topicStore, studySessionManager: studySessionManager)
        }
        .sheet(isPresented: $showExams) {
            ExamsView(studyDocumentStore: studyDocumentStore, topicStore: topicStore, examStore: examStore, rewardStore: rewardStore, studySessionManager: studySessionManager)
        }
        .sheet(isPresented: $showTutor) {
            TutorView(studyDocumentStore: studyDocumentStore, tutorStore: tutorStore)
        }
        .sheet(isPresented: $showPerformance) {
            PerformanceView(studyDocumentStore: studyDocumentStore, topicStore: topicStore, flashcardStore: flashcardStore, examStore: examStore)
        }
        .sheet(isPresented: $showStudyPlan) {
            StudyPlanView(
                studyDocumentStore: studyDocumentStore, topicStore: topicStore, flashcardStore: flashcardStore,
                examStore: examStore, studyPlanStore: studyPlanStore, rewardStore: rewardStore
            )
        }
        .sheet(isPresented: $showPaperReview) {
            PaperReviewView(studyDocumentStore: studyDocumentStore)
        }
        .sheet(isPresented: $showHelp) {
            HelpView()
        }
        .sheet(item: $askVisionRequest) { request in
            AskVisionView(chatSessionStore: chatSessionStore, initialQuery: request.query)
        }
        .sheet(isPresented: $showVisionReady) {
            VisionReadyView(bookmarkStore: bookmarkStore, offlineStore: offlineStore) { fileURL in
                tabManager.openOfflineFile(fileURL)
            }
        }
    }

    /// A real, disclosed test seam, not a fabricated feature: driving
    /// iOS's own system file-picker sheet (`.fileImporter`) reliably from
    /// XCUITest is a known, genuine platform limitation (the Files app's
    /// own UI, not this app's), so the upload step itself stays
    /// live-verified by hand rather than by CI. Everything downstream of
    /// a real uploaded file — processing, topic extraction, deletion —
    /// still needs real end-to-end proof, so a UI test launching with
    /// `-UITestSeedMaterial` gets one real fixture file genuinely copied
    /// onto disk and one real `StudyDocument` row inserted, the exact
    /// same real state `DocumentImport.importFile` would have produced
    /// had the picker actually been driven.
    private func seedMaterialsFixtureIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-UITestSeedMaterial") else { return }
        guard (try? studyDocumentStore.list())?.isEmpty ?? true else { return }
        do {
            let folder = try FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
            ).appendingPathComponent("StudyDocuments/ui-test-fixture", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let fileURL = folder.appendingPathComponent("fixture.txt")
            let contents = "This is a real fixture file for UI testing My Materials. It covers two real subjects: Photosynthesis and Cellular Respiration."
            try contents.write(to: fileURL, atomically: true, encoding: .utf8)

            let document = StudyDocument(
                id: "ui-test-fixture", title: "UI Test Fixture", originalFilename: "fixture.txt",
                fileType: .txt, contentPath: fileURL.path, sizeBytes: Int64(contents.utf8.count),
                status: .uploaded, processingError: nil, extractedText: nil, createdAt: Date()
            )
            try studyDocumentStore.insert(document)
        } catch {
            // A failed seed just means the UI test's own assertions won't
            // find the fixture and will fail loudly with a real reason —
            // never worth crashing a real user's launch over.
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

            Button(action: reloadActiveTab) {
                Image(systemName: "arrow.clockwise")
            }
            .accessibilityIdentifier("reloadButton")

            TextField("Search or enter address", text: $addressText, onCommit: navigateFromAddressBar)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .frame(height: 40)
                .padding(.horizontal, 14)
                // Direct port of bg_address_bar.xml: a true pill (radius ==
                // half the 40dp height, not the boxy radius-10 this had
                // drifted to) plus its own subtle 1dp stroke
                // (?attr/colorSurface fill + #33808080 stroke) — the stroke
                // had gone missing entirely on iOS.
                .background(RoundedRectangle(cornerRadius: 20).fill(DesignSystem.bgCard))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(white: 0.5).opacity(0.2), lineWidth: 1))
                .accessibilityIdentifier("addressBarField")

            Button(action: toggleBookmark) {
                Image(systemName: isBookmarked ? "star.fill" : "star")
            }
            .accessibilityIdentifier("bookmarkButton")
            .accessibilityLabel(isBookmarked ? "Remove bookmark" : "Add bookmark")

            Button(action: { showTabSwitcher = true }) {
                Text("\(tabManager.tabs.count)")
                    .font(.system(size: 13, weight: .bold))
                    // bg_tab_count.xml is a real 36dp square with a
                    // 1.5dp ?attr/colorOnBackground stroke (near-white in
                    // this app's dark theme) — this had shrunk to 24dp
                    // with a low-contrast borderCard stroke that barely
                    // shows up against bgCanvas.
                    .frame(width: 36, height: 36)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white, lineWidth: 1.5))
            }
            .accessibilityIdentifier("tabCountLabel")

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

            overflowMenu
        }
        .foregroundStyle(.white)
        .padding(8)
        .alert(
            "Save for Offline",
            isPresented: Binding(get: { saveOfflineStatus != nil }, set: { if !$0 { saveOfflineStatus = nil } })
        ) {
            Button("OK") { saveOfflineStatus = nil }
        } message: {
            Text(saveOfflineStatus ?? "")
        }
    }

    /// Direct equivalent of MainActivity.kt's showOverflowMenu() — every
    /// action beyond back/forward/bookmark lives here, in the real,
    /// user-specified order Android's own popup uses. The education
    /// screens are nested under a real "Education" submenu, matching
    /// Android's own real restructuring: MainActivity.kt's own doc
    /// comment on `showOverflowMenu()` confirms a single flat popup this
    /// size became genuinely unmanageable for Android too (its original
    /// PopupMenu silently drops nested submenus, so Android built a
    /// custom PopupWindow accordion instead — SwiftUI's `Menu` supports
    /// real nesting natively, so this is a direct equivalent, not a
    /// workaround). Minus the entries for features not built on iOS yet
    /// (Redeem, Autofill) — those appear here once their own phases land.
    /// VisionReady, the Study Material hub, and the dedicated Bookmarks
    /// screen named here before have all since landed.
    @ViewBuilder
    private var overflowMenu: some View {
        Menu {
            Button(action: { tabManager.createTab(url: nil) }) {
                Label("New Tab", systemImage: "plus")
            }
            .accessibilityIdentifier("menu_newTab")

            Button(action: { tabManager.createTab(url: nil, isPrivate: true) }) {
                Label("New Private Tab", systemImage: "eyeglasses")
            }
            .accessibilityIdentifier("menu_newPrivateTab")

            Button(action: { showDownloads = true }) {
                Label("Downloads", systemImage: "arrow.down.circle")
            }
            .accessibilityIdentifier("menu_downloads")

            Button(action: { showHistory = true }) {
                Label("History", systemImage: "clock")
            }
            .accessibilityIdentifier("menu_history")

            Button(action: { showBookmarksList = true }) {
                Label("Bookmarks", systemImage: "bookmark")
            }
            .accessibilityIdentifier("menu_bookmarks")

            Button(action: { showFocus = true }) {
                Label("Focus Mode", systemImage: "timer")
            }
            .accessibilityIdentifier("menu_focus")

            Button(action: { showRewards = true }) {
                Label("Rewards", systemImage: "star.circle")
            }
            .accessibilityIdentifier("menu_rewards")

            Button(action: { showRedeem = true }) {
                Label("Redeem", systemImage: "gift")
            }
            .accessibilityIdentifier("menu_redeem")

            Button(action: { showVisionReady = true }) {
                Label("VISION Ready", systemImage: "checkmark.shield")
            }
            .accessibilityIdentifier("menu_visionReady")

            Button(action: { showOfflineLibrary = true }) {
                Label("Offline Library", systemImage: "icloud.and.arrow.down")
            }
            .accessibilityIdentifier("menu_offlineLibrary")

            Button(action: { showTasks = true }) {
                Label("Tasks", systemImage: "checklist")
            }
            .accessibilityIdentifier("menu_tasks")

            Button(action: saveActiveTabOffline) {
                Label("Save Offline", systemImage: "square.and.arrow.down")
            }
            .disabled(tabManager.activeTab?.isNewTab ?? true)
            .accessibilityIdentifier("menu_saveOffline")

            Button(action: { showAdvisor = true }) {
                Label("Advisor", systemImage: "sparkles")
            }
            .accessibilityIdentifier("menu_advisor")

            Button(action: { askVisionRequest = AskVisionRequest(query: nil) }) {
                Label("Ask VISION", systemImage: "bubble.left.and.text.bubble.right")
            }
            .accessibilityIdentifier("menu_askVision")

            educationMenu

            Button(action: { showSettings = true }) {
                Label("Settings", systemImage: "gearshape")
            }
            .accessibilityIdentifier("menu_settings")

            Button(action: { showHelp = true }) {
                Label("Help", systemImage: "questionmark.circle")
            }
            .accessibilityIdentifier("menu_help")
        } label: {
            // Android's own overflow glyph (ic_menu_more) is plain
            // vertical dots with no circle outline — "ellipsis.circle"
            // added a ring Android's toolbar never has.
            Image(systemName: "ellipsis")
        }
        .accessibilityIdentifier("moreMenuButton")
    }

    /// Real nested submenu — Android's own "Education" accordion group
    /// (see `overflowMenu`'s own doc comment for why).
    @ViewBuilder
    private var educationMenu: some View {
        Menu {
            Button(action: { showMaterials = true }) {
                Label("My Materials", systemImage: "books.vertical")
            }
            .accessibilityIdentifier("menu_materials")

            Button(action: { showStudyMaterial = true }) {
                Label("Study Material", systemImage: "square.grid.2x2")
            }
            .accessibilityIdentifier("menu_studyMaterial")

            Button(action: { showFlashcards = true }) {
                Label("Flashcards", systemImage: "rectangle.on.rectangle")
            }
            .accessibilityIdentifier("menu_flashcards")

            Button(action: { showExams = true }) {
                Label("Exams", systemImage: "doc.text.magnifyingglass")
            }
            .accessibilityIdentifier("menu_exams")

            Button(action: { showTutor = true }) {
                Label("AI Tutor", systemImage: "bubble.left.and.bubble.right")
            }
            .accessibilityIdentifier("menu_tutor")

            Button(action: { showPerformance = true }) {
                Label("Performance", systemImage: "chart.bar")
            }
            .accessibilityIdentifier("menu_performance")

            Button(action: { showStudyPlan = true }) {
                Label("My Week", systemImage: "calendar")
            }
            .accessibilityIdentifier("menu_studyPlan")

            Button(action: { showRewrite = true }) {
                Label("Rewrite Writer", systemImage: "pencil.and.outline")
            }
            .accessibilityIdentifier("menu_rewrite")

            Button(action: { showPaperReview = true }) {
                Label("Paper Review", systemImage: "doc.text.magnifyingglass")
            }
            .accessibilityIdentifier("menu_paperReview")
        } label: {
            Label("Education", systemImage: "graduationcap")
        }
        .accessibilityIdentifier("menu_education")
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
                offlineStore: offlineStore,
                historyStore: historyStore,
                downloadStore: downloadStore,
                wellbeingStore: wellbeingStore,
                rewardStore: rewardStore,
                shortcutStore: shortcutStore,
                onNavigate: { destination in tabManager.navigateActiveTab(to: destination) },
                onAskVision: { query in askVisionRequest = AskVisionRequest(query: query) },
                onOpenVisionReady: { showVisionReady = true }
            )
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
    private func reloadActiveTab() { tabManager.activeTab?.webView.reload() }

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
                RewardEngine(store: rewardStore).awardIfEligible(type: .offlinePrep, note: "Saved \"\(item.title)\" for offline")
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
    let offlineStore: OfflineStore
    let historyStore: HistoryStore
    let downloadStore: DownloadStore
    let wellbeingStore: WellbeingStore
    let rewardStore: RewardStore
    let shortcutStore: ShortcutStore
    let onNavigate: (String) -> Void
    let onAskVision: (String) -> Void
    let onOpenVisionReady: () -> Void

    var body: some View {
        if tab.isNewTab {
            NewTabView(
                bookmarkStore: bookmarkStore, offlineStore: offlineStore, wellbeingStore: wellbeingStore, rewardStore: rewardStore,
                shortcutStore: shortcutStore,
                onNavigate: onNavigate, onAskVision: onAskVision, onOpenVisionReady: onOpenVisionReady
            )
        } else {
            VStack(spacing: 0) {
                // Real page-load progress — the iOS counterpart of
                // activity_main.xml's own toolbar ProgressBar, bound to
                // WebChromeClient.onProgressChanged on Android. Only
                // takes up real layout space while a page is actually
                // loading, matching Android's View.GONE when idle.
                if tab.isLoading {
                    ProgressView(value: tab.estimatedProgress, total: 1.0)
                        .progressViewStyle(.linear)
                        // activity_main.xml's progressBar has no explicit
                        // tint of its own — it just inherits
                        // Theme.Vision's colorAccent, which is
                        // vision_blue, not vision_purple.
                        .tint(DesignSystem.visionBlue)
                        .frame(height: 2)
                        .accessibilityIdentifier("pageLoadProgress")
                }
                WebViewRepresentable(tab: tab, historyStore: historyStore, downloadStore: downloadStore, wellbeingStore: wellbeingStore)
            }
        }
    }
}
