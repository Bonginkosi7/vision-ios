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
    /// While the address bar is being edited it shows the full address; otherwise just the site, like Safari.
    @FocusState private var addressFocused: Bool
    @State private var isBookmarked: Bool = false
    @State private var showHistory = false
    @State private var showTabSwitcher = false
    @State private var showBookmarksList = false
    @State private var showDownloads = false
    @State private var showOfflineLibrary = false
    @State private var showSettings = false
    @State private var readerArticle: ReaderArticle?
    @State private var readerUnavailable = false
    @State private var autofillChoices: [SavedCredential] = []
    @State private var showAutofillChoices = false
    @State private var autofillNoLoginFor: String?
    @State private var autofillNoField = false
    @State private var showRewrite = false
    @State private var showFocus = false
    @State private var showTasks = false
    @State private var showAdvisor = false
    @State private var showRewards = false
    @State private var showRedeem = false
    @State private var showOverview = false
    @State private var showMaterials = false
    @State private var showStudyMaterial = false
    @State private var showFlashcards = false
    @State private var showExams = false
    @State private var showTutor = false
    @State private var showPerformance = false
    @State private var showStudyPlan = false
    @State private var showPaperReview = false
    @State private var askVisionRequest: AskVisionRequest?
    @State private var showVisionReady = false
    @State private var saveOfflineStatus: String?
    @State private var translateUnavailable = false
    /// Whether the focused tab is showing the home page — the bottom address bar is only for pages.
    @State private var onHomePage = true
    /// Whether the focused tab asks for the desktop site — kept here so the menu's label follows it.
    @State private var activeDesktopSite = false

    var body: some View {
        VStack(spacing: 0) {
            content
            // Address bar and controls live at the bottom, within thumb
            // reach, like Safari.
            Rectangle().fill(DesignSystem.borderCard).frame(height: 1)
            addressBar
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
                        Text("Private").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    }
                    .accessibilityIdentifier("privateSessionCover")
            }
        }
        .task {
            // Offline Ask VISION downloads by itself shortly after launch (the homepage card
            // shows its progress, with Cancel) unless it is already there or the user said no.
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            LocalModelManager.shared.autoStartIfNeeded()
        }
        .onAppear {
            if tabManager.tabs.isEmpty {
                tabManager.restorePinnedTabs()
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
            #if DEBUG
            // UI tests can't make a real page ask for the camera, so they ask for one remembered answer to look at.
            if ProcessInfo.processInfo.arguments.contains("-UITestSeedSitePermission") {
                SitePermissionStore.shared.set(origin: "https://uitest-site.example.com", kind: .camera, granted: true)
            }
            #endif
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
        .confirmationDialog("Choose an account to fill in", isPresented: $showAutofillChoices, titleVisibility: .visible) {
            ForEach(autofillChoices) { credential in
                Button(credential.username) { fill(credential) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("No saved login for this site", isPresented: Binding(get: { autofillNoLoginFor != nil }, set: { if !$0 { autofillNoLoginFor = nil } })) {
            Button("Open Settings") { showSettings = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("VISION has no saved password for \(autofillNoLoginFor ?? "this site"). Add one in Settings → Saved passwords.")
        }
        .alert("Nothing to fill in", isPresented: $autofillNoField) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This page doesn't show a password field right now. Open the login form first, then try Autofill again.")
        }
        .sheet(item: $readerArticle) { article in
            ReaderView(article: article)
        }
        .alert("Translate Page", isPresented: $translateUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Only public https:// web pages can be translated.")
        }
        .alert("Reader View", isPresented: $readerUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This page doesn't look like an article, so there's nothing to simplify.")
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(historyStore: historyStore) { url in
                _ = tabManager.createTab(url: url)
            }
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
        .sheet(isPresented: $showOverview) {
            TodayOverviewView(wellbeingStore: wellbeingStore)
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
        // Always a fresh fixture, and never "only when empty": a device (or an earlier test run)
        // may already hold other materials, or a processed copy of this one.
        try? studyDocumentStore.remove(id: "ui-test-fixture")
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

    /// Every toolbar button gets its own 44pt target; the address field takes
    /// whatever width is left. Left group (Back, Forward, Reload), flexible
    /// field, right group (Bookmark, Tabs, More) — the groups never shrink, so
    /// on a narrow phone it's the field that gives up width, not the touch
    /// targets. Targets sit edge to edge in a zero-spacing stack, so none of
    /// them can overlap another's hit area.
    private static let toolbarTarget: CGFloat = 44

    @ViewBuilder
    private func toolbarIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .regular))
            .frame(width: Self.toolbarTarget, height: Self.toolbarTarget)
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private var addressBar: some View {
        // Safari layout: the address field gets the full width on its own
        // row; the six controls sit below it, spread evenly, each in its
        // own 44pt target.
        VStack(spacing: 2) {
            // The address bar belongs to pages: on the home page the search box up top is where you type, so only
            // the Focus / Private markers (when they apply) stay down here.
            if !onHomePage {
                HStack(spacing: 8) {
                    TextField("Search or enter address", text: $addressText, onCommit: navigateFromAddressBar)
                        .focused($addressFocused)
                        .multilineTextAlignment(addressFocused ? .leading : .center)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .frame(height: 40)
                        .padding(.horizontal, 14)
                        // Direct port of bg_address_bar.xml: a true pill (radius ==
                        // half the 40dp height) plus its own subtle 1dp stroke
                        // (?attr/colorSurface fill + #33808080 stroke).
                        .background(RoundedRectangle(cornerRadius: 20).fill(DesignSystem.addressField))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(DesignSystem.addressFieldBorder, lineWidth: 1))
                        .accessibilityIdentifier("addressBarField")
                        .onChange(of: addressFocused) { focused in
                            // Tapping the bar shows the whole address, selected so typing replaces it.
                            syncAddressBar()
                            if focused {
                                DispatchQueue.main.async { UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil) }
                            }
                        }
                    sessionMarkers
                }
                .padding(.horizontal, 12)
            } else if focusManager.activeSession != nil || tabManager.activeTab?.isPrivate == true {
                HStack(spacing: 8) {
                    Spacer()
                    sessionMarkers
                }
                .padding(.horizontal, 12)
            }

            HStack(spacing: 0) {
                Button(action: goBack) {
                    toolbarIcon("chevron.left")
                }
                .disabled(!canGoBack)
                .accessibilityLabel("Back")
                .accessibilityIdentifier("backButton")
                .frame(maxWidth: .infinity)

                Button(action: goForward) {
                    toolbarIcon("chevron.right")
                }
                .disabled(!canGoForward)
                .accessibilityLabel("Forward")
                .accessibilityIdentifier("forwardButton")
                .frame(maxWidth: .infinity)

                Button(action: reloadActiveTab) {
                    toolbarIcon("arrow.clockwise")
                }
                .accessibilityLabel("Reload")
                .accessibilityIdentifier("reloadButton")
                .frame(maxWidth: .infinity)

                Button(action: toggleBookmark) {
                    toolbarIcon(isBookmarked ? "star.fill" : "star")
                }
                .accessibilityIdentifier("bookmarkButton")
                .accessibilityLabel(isBookmarked ? "Remove bookmark" : "Add bookmark")
                .frame(maxWidth: .infinity)

                Button(action: { showTabSwitcher = true }) {
                    Text("\(tabManager.tabs.count)")
                        .font(.system(size: 13, weight: .bold))
                        // bg_tab_count.xml is a real 36dp square with a 1.5dp
                        // near-white stroke — kept exactly, now centred in a
                        // full 44pt target.
                        .frame(width: 30, height: 30)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white, lineWidth: 1.5))
                        .frame(width: Self.toolbarTarget, height: Self.toolbarTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("tabCountLabel")
                .frame(maxWidth: .infinity)

                overflowMenu
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 4)
        }
        .foregroundStyle(.white)
        .padding(.top, 8)
        .padding(.bottom, 2)
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
    private var sessionMarkers: some View {
        if focusManager.activeSession != nil {
            Text("Focus")
                .font(.system(size: 11, weight: .semibold))
                .fixedSize()
                .accessibilityIdentifier("focusActiveIndicator")
        }
        if tabManager.activeTab?.isPrivate == true {
            Text("Private")
                .font(.system(size: 11, weight: .semibold))
                .fixedSize()
                .accessibilityIdentifier("privateIndicator")
        }
    }

    /// The less-used screens, tucked into a submenu so the main menu fits the screen with Settings fully in view —
    /// Advisor, Points, the offline library and Offline Readiness are also on the homepage.
    @ViewBuilder
    private var moreMenu: some View {
        Menu {
            Button(action: { showAdvisor = true }) {
                Label("Advisor", systemImage: "sparkles")
            }
            .accessibilityIdentifier("menu_advisor")

            Button(action: { showTasks = true }) {
                Label("Tasks", systemImage: "checklist")
            }
            .accessibilityIdentifier("menu_tasks")

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

        } label: {
            Label("More", systemImage: "ellipsis.circle")
        }
        .accessibilityIdentifier("menu_more")
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

            // Both act on the open page, so they share one row — keeps the menu short enough to fit the screen.
            ControlGroup {
                Button(action: saveActiveTabOffline) {
                    Label("Save Offline", systemImage: "square.and.arrow.down")
                }
                .disabled(tabManager.activeTab?.isNewTab ?? true)
                .accessibilityIdentifier("menu_saveOffline")

                Button(action: autofillActiveTab) {
                    Label("Autofill", systemImage: "key")
                }
                .disabled(tabManager.activeTab?.isNewTab ?? true)
                .accessibilityIdentifier("menu_autofill")

                Button(action: openReaderView) {
                    Label("Reader", systemImage: "text.justify.left")
                }
                .disabled(tabManager.activeTab?.isNewTab ?? true)
                .accessibilityIdentifier("menu_reader")
            }

            // More actions on the open page: translate it (with Google Translate), keep it as a pinned tab, show it beside another tab.
            ControlGroup {
                Button(action: translateActivePage) {
                    Label(isActiveTabTranslated ? "Original" : "Translate", systemImage: "character.bubble")
                }
                .disabled(tabManager.activeTab?.isNewTab ?? true)
                .accessibilityIdentifier("menu_translate")

                Button(action: togglePinActiveTab) {
                    Label(tabManager.activeTab?.isPinned == true ? "Unpin" : "Pin", systemImage: tabManager.activeTab?.isPinned == true ? "pin.slash" : "pin")
                }
                .disabled(tabManager.activeTab.map { $0.isNewTab || $0.isPrivate } ?? true)
                .accessibilityIdentifier("menu_pin")

                Button(action: toggleSplit) {
                    Label(tabManager.isSplit ? "Unsplit" : "Split", systemImage: "rectangle.split.2x1")
                }
                .accessibilityIdentifier("menu_split")
            }

            // Share the open page, search inside it, or ask for the desktop version of the site.
            ControlGroup {
                if let url = shareableURL {
                    ShareLink(item: url, subject: Text(tabManager.activeTab?.title ?? "")) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("menu_share")
                } else {
                    Button(action: {}) { Label("Share", systemImage: "square.and.arrow.up") }
                        .disabled(true)
                        .accessibilityIdentifier("menu_share")
                }

                Button(action: findInPage) {
                    Label("Find", systemImage: "magnifyingglass")
                }
                .disabled(tabManager.activeTab?.isNewTab ?? true)
                .accessibilityIdentifier("menu_find")

                Button(action: toggleDesktopSite) {
                    Label(activeDesktopSite ? "Mobile" : "Desktop", systemImage: "desktopcomputer")
                }
                .disabled(tabManager.activeTab?.isNewTab ?? true)
                .accessibilityIdentifier("menu_desktopSite")
            }

            Button(action: { askVisionRequest = AskVisionRequest(query: nil) }) {
                Label("Ask VISION", systemImage: "bubble.left.and.text.bubble.right")
            }
            .accessibilityIdentifier("menu_askVision")

            educationMenu

            moreMenu

            Button(action: { showSettings = true }) {
                Label("Settings", systemImage: "gearshape")
            }
            .accessibilityIdentifier("menu_settings")
        } label: {
            // Android's own overflow glyph (ic_menu_more) is plain
            // vertical dots with no circle outline — "ellipsis.circle"
            // added a ring Android's toolbar never has.
            toolbarIcon("ellipsis")
        }
        .accessibilityLabel("More")
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
            Group {
                if tabManager.isSplit {
                    SplitPanes(tabManager: tabManager, pane: { pane in paneContent(for: pane, isSplit: true) })
                } else {
                    paneContent(for: tab, isSplit: false)
                }
            }
            .onReceive(tab.$url) { _ in syncAddressBar() }
            .onReceive(tab.$requestsDesktopSite) { activeDesktopSite = $0 }
            .onReceive(tab.$isNewTab) { isHome in
                onHomePage = isHome
                refreshBookmarkState()
            }
        } else {
            ProgressView().tint(.white)
        }
    }

    /// One tab's page — the New Tab homepage or its web view. In split view each pane navigates its own tab.
    private func paneContent(for tab: BrowserTab, isSplit: Bool) -> some View {
        ActiveTabContent(
            tab: tab,
            bookmarkStore: bookmarkStore,
            offlineStore: offlineStore,
            historyStore: historyStore,
            downloadStore: downloadStore,
            wellbeingStore: wellbeingStore,
            rewardStore: rewardStore,
            shortcutStore: shortcutStore,
            onNavigate: { destination in
                if isSplit { tabManager.navigate(tab, to: destination) } else { tabManager.navigateActiveTab(to: destination) }
            },
            onAskVision: { query in askVisionRequest = AskVisionRequest(query: query.isEmpty ? nil : query) },
            onOpen: { destination in openHome(destination) },
            onOpenSavedPage: { fileURL in tabManager.openOfflineFile(fileURL) }
        )
    }

    /// Every destination the homepage can open is an existing sheet here.
    private func openHome(_ destination: HomeDestination) {
        switch destination {
        case .advisor: showAdvisor = true
        case .settings: showSettings = true
        case .overview: showOverview = true
        case .points: showRewards = true
        case .visionReady: showVisionReady = true
        case .offlineLibrary: showOfflineLibrary = true
        case .tasks: showTasks = true
        case .focus: showFocus = true
        case .flashcards: showFlashcards = true
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

    private var isActiveTabTranslated: Bool {
        TranslateLogic.isTranslated(tabManager.activeTab?.url ?? "")
    }

    /// Translates the open page into the device's language with Google Translate, or goes back to the original.
    private func translateActivePage() {
        guard let tab = tabManager.activeTab, !tab.isNewTab else { return }
        let target: String?
        if TranslateLogic.isTranslated(tab.url) {
            target = TranslateLogic.originalURL(of: tab.url)
        } else {
            let language = Locale.current.language
            let code = TranslateLogic.targetCode(languageCode: language.languageCode?.identifier, script: language.script?.identifier)
            target = TranslateLogic.translatedURL(for: tab.url, targetCode: code)
        }
        if let target { tabManager.navigateActiveTab(to: target) } else { translateUnavailable = true }
    }

    /// The open page's address, when it is a real web page that can be shared.
    private var shareableURL: URL? {
        guard let tab = tabManager.activeTab, !tab.isNewTab, let url = URL(string: tab.url),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        return url
    }

    /// Opens iOS's own find bar over the page.
    private func findInPage() {
        guard let tab = tabManager.activeTab, !tab.isNewTab else { return }
        tab.webView.isFindInteractionEnabled = true
        DispatchQueue.main.async { tab.webView.findInteraction?.presentFindNavigator(showingReplace: false) }
    }

    /// Asks the open page's site for its desktop version (or the phone version again) and reloads it.
    private func toggleDesktopSite() {
        guard let tab = tabManager.activeTab, !tab.isNewTab else { return }
        tab.requestsDesktopSite.toggle()
        tab.webView.reload()
    }

    private func togglePinActiveTab() {
        guard let tab = tabManager.activeTab else { return }
        if tab.isPinned { tabManager.unpin(tab) } else { tabManager.pin(tab) }
    }

    private func toggleSplit() {
        if tabManager.isSplit { tabManager.closeSplit() } else { tabManager.openSplit() }
    }

    /// Back from a tab's first page returns to the home page (like Chrome's New Tab page), and Forward goes on to
    /// that page again — the home page is the start of every tab's history.
    private var canGoBack: Bool {
        guard let tab = tabManager.activeTab else { return false }
        return tab.webView.canGoBack || !onHomePage
    }

    private var canGoForward: Bool {
        guard let tab = tabManager.activeTab else { return false }
        return onHomePage ? tab.webView.url != nil : tab.webView.canGoForward
    }

    private func goBack() {
        guard let tab = tabManager.activeTab else { return }
        if tab.webView.canGoBack {
            tab.webView.goBack()
        } else if !tab.isNewTab {
            tab.isNewTab = true
            syncAddressBar()
        }
    }

    private func goForward() {
        guard let tab = tabManager.activeTab else { return }
        if tab.isNewTab, tab.webView.url != nil {
            tab.isNewTab = false
            syncAddressBar()
        } else if tab.webView.canGoForward {
            tab.webView.goForward()
        }
    }
    private func reloadActiveTab() { tabManager.activeTab?.webView.reload() }

    private func syncAddressBar() {
        let url = tabManager.activeTab?.url ?? ""
        addressText = addressFocused ? url : AddressDisplay.text(for: url)
        refreshBookmarkState()
    }

    private func refreshBookmarkState() {
        // The home page isn't a page to bookmark, even when the tab still holds the page it came back from.
        guard let tab = tabManager.activeTab, !tab.isNewTab, !tab.url.isEmpty else {
            isBookmarked = false
            return
        }
        let url = tab.url
        isBookmarked = (try? bookmarkStore.isBookmarked(url: url)) != nil
    }

    private func toggleBookmark() {
        guard let tab = tabManager.activeTab, !tab.isNewTab, !tab.url.isEmpty else { return }
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

    /// Reader View for the open page: Readability runs inside the page and hands back the article text.
    private func openReaderView() {
        guard let tab = tabManager.activeTab, !tab.isNewTab, ReaderCore.canRead(url: tab.url),
              let source = Bundle.main.url(forResource: "Readability", withExtension: "js").flatMap({ try? String(contentsOf: $0, encoding: .utf8) })
        else {
            readerUnavailable = true
            return
        }
        let script = ReaderCore.buildExtractionScript(readabilitySource: source)
        Task { @MainActor in
            let raw = try? await tab.webView.evaluateJavaScript(script)
            if let article = ReaderCore.parseExtraction(raw, id: UUID().uuidString, sourceURL: tab.url) {
                readerArticle = article
            } else {
                readerUnavailable = true
            }
        }
    }

    /// Fills the open page's login form from a saved password — matched on the page's exact origin only.
    private func autofillActiveTab() {
        guard let tab = tabManager.activeTab, !tab.isNewTab, let origin = AutofillLogic.originOf(tab.url) else {
            autofillNoField = true
            return
        }
        let matches = CredentialStore.shared.find(origin: origin)
        if matches.isEmpty {
            autofillNoLoginFor = origin
        } else if matches.count == 1 {
            fill(matches[0])
        } else {
            autofillChoices = matches
            showAutofillChoices = true
        }
    }

    private func fill(_ credential: SavedCredential) {
        Task { @MainActor in
            guard await DeviceAuth.authenticate(reason: "Fill in your saved password"),
                  let password = CredentialStore.shared.reveal(id: credential.id),
                  let webView = tabManager.activeTab?.webView
            else { return }
            let script = AutofillLogic.buildFillScript(username: credential.username, password: password)
            let filled = (try? await webView.evaluateJavaScript(script)) as? Bool
            if filled != true { autofillNoField = true }
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
    let onOpen: (HomeDestination) -> Void
    let onOpenSavedPage: (URL) -> Void

    var body: some View {
        if tab.isNewTab {
            NewTabView(
                bookmarkStore: bookmarkStore, offlineStore: offlineStore, wellbeingStore: wellbeingStore, rewardStore: rewardStore,
                shortcutStore: shortcutStore,
                onNavigate: onNavigate, onAskVision: onAskVision, onOpen: onOpen, onOpenSavedPage: onOpenSavedPage
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
                        .tint(.white)
                        .frame(height: 2)
                        .accessibilityIdentifier("pageLoadProgress")
                }
                WebViewRepresentable(tab: tab, historyStore: historyStore, downloadStore: downloadStore, wellbeingStore: wellbeingStore)
            }
        }
    }
}


/// Two tabs on screen at once — side by side when there is room, one above the other on a narrow screen — with a
/// draggable divider. The focused pane (the one the address bar and toolbar act on) has a white outline; touching a
/// page, or its header, focuses it. Each header has swap and close-this-side controls.
private struct SplitPanes<Pane: View>: View {
    @ObservedObject var tabManager: TabManager
    let pane: (BrowserTab) -> Pane

    var body: some View {
        if let tabs = tabManager.splitTabs {
            GeometryReader { geo in
                let axis = SplitLayout.axis(width: geo.size.width, height: geo.size.height)
                let sideBySide = axis == .sideBySide
                let extent = sideBySide ? geo.size.width : geo.size.height
                let first = SplitLayout.firstPaneLength(extent: extent, ratio: tabManager.splitRatio)
                let layout = sideBySide ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
                layout {
                    SplitPane(tab: tabs.first, name: "first", tabManager: tabManager, content: pane(tabs.first))
                        .frame(width: sideBySide ? first : nil, height: sideBySide ? nil : first)
                    divider(sideBySide: sideBySide, extent: extent)
                    SplitPane(tab: tabs.second, name: "second", tabManager: tabManager, content: pane(tabs.second))
                }
                .coordinateSpace(name: "splitArea")
            }
        }
    }

    private func divider(sideBySide: Bool, extent: Double) -> some View {
        ZStack {
            Color.clear
            Capsule()
                .fill(Color.white.opacity(0.45))
                .frame(width: sideBySide ? 4 : 44, height: sideBySide ? 44 : 4)
        }
        .frame(width: sideBySide ? SplitLayout.dividerThickness : nil, height: sideBySide ? nil : SplitLayout.dividerThickness)
        .frame(maxWidth: sideBySide ? nil : .infinity, maxHeight: sideBySide ? .infinity : nil)
        .background(DesignSystem.bgCanvas)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("splitArea")).onChanged { value in
                let position = sideBySide ? value.location.x : value.location.y
                tabManager.splitRatio = SplitLayout.ratio(forDividerAt: position, extent: extent)
            }
        )
        .accessibilityElement()
        .accessibilityLabel("Resize split view")
        .accessibilityIdentifier("splitDivider")
    }
}

private struct SplitPane<Content: View>: View {
    @ObservedObject var tab: BrowserTab
    let name: String
    @ObservedObject var tabManager: TabManager
    let content: Content

    private var isFocused: Bool { tabManager.activeTab?.id == tab.id }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Button(action: { tabManager.focus(tab) }) {
                    Text(tab.isNewTab ? "New Tab" : (tab.title.isEmpty ? (FaviconCache.host(from: tab.url) ?? tab.url) : tab.title))
                        .font(.system(size: 12, weight: isFocused ? .semibold : .regular))
                        .foregroundStyle(isFocused ? .white : DesignSystem.textMuted2)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("splitPaneTitle_\(name)")

                Button(action: { tabManager.swapSplit() }) {
                    Image(systemName: "arrow.left.arrow.right").font(.system(size: 12)).frame(width: 32, height: 28)
                }
                .accessibilityLabel("Swap sides")
                .accessibilityIdentifier("splitSwap_\(name)")

                Button(action: {
                    // Closing a side keeps the *other* tab on screen; both stay open in the tab switcher.
                    if let tabs = tabManager.splitTabs { tabManager.closeSplit(keeping: tabs.first.id == tab.id ? tabs.second : tabs.first) }
                }) {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .semibold)).frame(width: 32, height: 28)
                }
                .accessibilityLabel("Close this side")
                .accessibilityIdentifier("splitClose_\(name)")
            }
            .foregroundStyle(.white)
            .padding(.leading, 10)
            .padding(.trailing, 2)
            .frame(height: 30)
            .background(DesignSystem.bgCard)

            content
                .simultaneousGesture(TapGesture().onEnded { tabManager.focus(tab) })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(Rectangle().stroke(isFocused ? Color.white.opacity(0.85) : Color.clear, lineWidth: 2).allowsHitTesting(false))
        .clipped()
    }
}
