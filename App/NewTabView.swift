import SwiftUI
import VisionCore

private enum NewsStatus {
    case loading, empty, loaded
}

private struct HomeFeatureCard: Identifiable {
    let id: String
    let icon: String
    let title: String
    let description: String
    let destination: HomeDestination
    let chip: String?
}

/// The Vision homepage (new-tab page): header with the Online / Offline
/// toggle, a greeting, the Ask box, the user's shortcuts, four cards that open
/// existing screens (Advisor, Settings, Today's Overview, Points), and one
/// content section that depends on the mode — live BBC headlines when Online,
/// saved pages and on-device tools when Offline.
///
/// The Online / Offline control reflects real state only: the device's actual
/// connection (`ConnectivityMonitor`) plus the user's saved Offline Mode choice
/// (`HomeConnectivityMode`). Offline Mode here is a homepage-level choice — it
/// stops live fetches and shows saved content — and does not cut the device's
/// network; the status line says so.
///
/// Kept from the previous homepage, unchanged in behaviour: the Ask box (a URL
/// navigates, anything else opens Ask VISION), user-managed shortcuts, the
/// real Advisor nudge with its actions, Offline Readiness, and the BBC News
/// section. There is no bookmarks list here on purpose — Android's new-tab
/// never had one (`bookmarkStore` is read only to compute Offline Readiness);
/// bookmarks live in the dedicated Bookmarks screen.
///
/// Not ported: Android's Weather pill (a location-permission + API
/// integration that deserves its own phase).
struct NewTabView: View {
    @ObservedObject var bookmarkStore: BookmarkStore
    @ObservedObject var offlineStore: OfflineStore
    @ObservedObject var wellbeingStore: WellbeingStore
    @ObservedObject var rewardStore: RewardStore
    @ObservedObject var shortcutStore: ShortcutStore
    let onNavigate: (String) -> Void
    let onAskVision: (String) -> Void
    let onOpen: (HomeDestination) -> Void
    let onOpenSavedPage: (URL) -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    @ObservedObject private var connectivity = ConnectivityMonitor.shared
    @AppStorage(AppSettings.offlineModeKey) private var offlineModeEnabled = false
    @AppStorage(ProfileStore.nameKey) private var profileName = ""

    @State private var bookmarks: [Bookmark] = []
    @State private var shortcuts: [Shortcut] = []
    @State private var savedPages: [OfflineItem] = []
    @State private var headlines: [NewsHeadline] = []
    @State private var newsStatus: NewsStatus = .loading
    @State private var askText = ""
    @State private var showAddShortcut = false
    @State private var showCannotGoOnline = false
    @State private var newShortcutTitle = ""
    @State private var newShortcutUrl = ""

    @State private var advisorSuggestion: AdvisorSuggestion?
    @State private var advisorDismissed = false
    @State private var readiness: ReadinessResult?
    @State private var overview = TodayOverviewSnapshot(focusLabel: "0m", breaks: 0, sites: 0, tabs: 0)
    @State private var pointsBalance = 0

    /// Shortcut icons: 44pt (they were 52 and read as too large).
    private static let shortcutIconSize: CGFloat = 44

    private var mode: HomeConnectivityMode {
        .resolve(deviceOnline: connectivity.isOnline, offlineModeEnabled: offlineModeEnabled)
    }

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                Image("NewTabBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
            .ignoresSafeArea()
            LinearGradient(
                colors: [HomeTheme.scrim.opacity(0.20), HomeTheme.scrim.opacity(0.50), HomeTheme.scrim.opacity(0.86)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20).padding(.top, 28)

                Text(greeting)
                    .font(.system(size: 34, weight: .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20).padding(.top, 36)
                    .accessibilityIdentifier("newTabGreeting")

                modeStatus
                    .padding(.horizontal, 20).padding(.top, 6)

                // Pinned outside the ScrollView on purpose: with the Ask box
                // inside it, the keyboard's own scroll-into-view adjustment
                // shifted the submit button out from under an already-computed
                // tap coordinate (a real CI-caught bug — the tap reported
                // success but the action never ran).
                askVisionBox
                    .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 8)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        shortcutsRow
                        OfflineModelPromptCard().padding(.horizontal, 20)
                        advisorNudge.padding(.horizontal, 20)
                        featureCards.padding(.horizontal, 20)
                        modeContent.padding(.horizontal, 20)
                        footer.padding(.horizontal, 20)
                    }
                    .padding(.vertical, 12)
                    .padding(.bottom, 12)
                }
            }
            .frame(maxWidth: 820)
        }
        .environment(\.colorScheme, .dark)
        .onAppear {
            refresh()
            if !mode.isOffline { Task { await refreshNews() } }
        }
        .onChange(of: mode.isOffline) { offline in
            refresh()
            if !offline { Task { await refreshNews() } }
        }
        .alert("Add shortcut", isPresented: $showAddShortcut) {
            TextField("Title", text: $newShortcutTitle)
            TextField("URL", text: $newShortcutUrl)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            Button("Add", action: addShortcut)
            Button("Cancel", role: .cancel) {
                newShortcutTitle = ""
                newShortcutUrl = ""
            }
        }
    }

    // MARK: - Header, greeting, mode status

    private var header: some View {
        HStack(spacing: 8) {
            VisionMark(height: 26)
                .accessibilityIdentifier("homeHeaderMark")
            Spacer(minLength: 8)
            HomeModeToggle(
                mode: mode,
                onOnline: {
                    switch mode {
                    case .online:
                        break
                    case .offlineByChoice:
                        offlineModeEnabled = false
                        Task { @MainActor in AnalyticsClient.shared.track(AnalyticsEvent.offlineModeExited) }
                    case .offlineNoConnection:
                        showCannotGoOnline = true
                    }
                },
                onOffline: {
                    if mode == .online {
                        offlineModeEnabled = true
                        Task { @MainActor in AnalyticsClient.shared.track(AnalyticsEvent.offlineModeEntered) }
                    }
                }
            )
        }
        .alert("Can't go online", isPresented: $showCannotGoOnline) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(HomeConnectivityMode.cannotGoOnlineExplanation)
        }
    }

    private var modeStatus: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(mode.isOffline ? Color.clear : Color.white)
                .overlay(Circle().stroke(Color.white.opacity(0.75), lineWidth: 1.5))
                .frame(width: 8, height: 8)
                .padding(.top, 5)
            Text(mode.statusText)
                .font(.system(size: 13)).foregroundStyle(HomeTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("homeModeStatus")
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let base: String
        switch hour {
        case 5..<12: base = "Good morning"
        case 12..<17: base = "Good afternoon"
        case 17..<21: base = "Good evening"
        default: base = "Good night"
        }
        // The name set in Settings → Profile, when there is one.
        let name = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? base : "\(base), \(name)"
    }

    // MARK: - Ask box

    private var askVisionBox: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium)).foregroundStyle(HomeTheme.textSecondary)
                .accessibilityHidden(true)
            TextField(
                "", text: $askText,
                prompt: Text("Ask anything or enter a website").foregroundColor(Color.white.opacity(0.5))
            )
            .textFieldStyle(.plain)
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .submitLabel(.go)
            .onSubmit(submitAsk)
            .foregroundStyle(.white)
            .accessibilityLabel("Ask anything or enter a website")
            .accessibilityIdentifier("newTabSearchInput")
            Button(action: submitAsk) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white))
            }
            .accessibilityLabel("Ask")
            .accessibilityIdentifier("newTabAskSubmit")
        }
        .padding(.leading, 18).padding(.trailing, 10)
        .frame(height: 56)
        .background(Capsule().fill(Color.black.opacity(0.42)))
        .overlay(Capsule().stroke(HomeTheme.stroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
    }

    /// A URL or domain navigates, exactly like the address bar. Anything else
    /// goes to Ask VISION — this box is not the address bar, even though it
    /// accepts URLs too (port of NewTabController.kt's submitAsk()).
    private func submitAsk() {
        let trimmed = askText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        askText = ""
        if AddressResolver.isDirectUrl(trimmed) {
            let destination = (trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")) ? trimmed : "https://\(trimmed)"
            onNavigate(destination)
        } else {
            onAskVision(trimmed)
        }
    }

    // MARK: - Shortcuts

    private var shortcutsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 6) {
                ForEach(shortcuts) { shortcut in
                    shortcutTile(shortcut)
                }
                addShortcutTile
            }
            .padding(.horizontal, 20)
        }
        .accessibilityIdentifier("newTabShortcutsRow")
    }

    private func shortcutTile(_ shortcut: Shortcut) -> some View {
        Button(action: { onNavigate(shortcut.url) }) {
            VStack(spacing: 6) {
                FaviconView(host: shortcutFaviconHost(shortcut.url), size: Self.shortcutIconSize, remoteLookup: true)
                Text(shortcut.title)
                    .font(.system(size: 11)).foregroundStyle(HomeTheme.textSecondary)
                    .lineLimit(1)
                    .frame(width: 64)
            }
        }
        .accessibilityIdentifier("newTabShortcut_\(shortcut.id ?? 0)")
        .contextMenu {
            Button("Remove", role: .destructive) {
                try? shortcutStore.remove(id: shortcut.id ?? 0)
                refresh()
            }
        }
    }

    private var addShortcutTile: some View {
        Button(action: { showAddShortcut = true }) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: Self.shortcutIconSize * 0.26, style: .continuous).fill(Color.white.opacity(0.10))
                    RoundedRectangle(cornerRadius: Self.shortcutIconSize * 0.26, style: .continuous).stroke(HomeTheme.stroke, lineWidth: 1)
                    Image(systemName: "plus").foregroundStyle(.white)
                }
                .frame(width: Self.shortcutIconSize, height: Self.shortcutIconSize)
                Text("Add").font(.system(size: 11)).foregroundStyle(HomeTheme.textSecondary)
            }
        }
        .accessibilityIdentifier("newTabAddShortcut")
    }

    /// web.whatsapp.com has no favicon of its own indexed by the lookup
    /// service (it 404s to a generic globe) — whatsapp.com has the real logo,
    /// the same host substitution NewTabController.kt makes for this one case.
    private func shortcutFaviconHost(_ urlString: String) -> String {
        let host = URL(string: urlString)?.host ?? urlString
        return host == "web.whatsapp.com" ? "whatsapp.com" : host
    }

    private func addShortcut() {
        let title = newShortcutTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        var url = newShortcutUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        newShortcutTitle = ""
        newShortcutUrl = ""
        guard !title.isEmpty, !url.isEmpty else { return }
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "https://\(url)"
        }
        try? shortcutStore.add(title: title, url: url)
        refresh()
    }

    // MARK: - Advisor nudge

    /// Shown only when AdvisorLogic genuinely has a suggestion (e.g. a long
    /// continuous session). Take a break / Dismiss behave exactly as before.
    @ViewBuilder
    private var advisorNudge: some View {
        if let advisorSuggestion, !advisorDismissed {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles").font(.system(size: 13, weight: .semibold)).accessibilityHidden(true)
                    Text("Vision Advisor").font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(HomeTheme.textSecondary)
                Text(advisorSuggestion.message)
                    .font(.system(size: 16)).foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("advisorMessage")
                HStack(spacing: 10) {
                    ForEach(advisorSuggestion.actions, id: \.label) { action in
                        Button(action: { performAdvisorAction(action.id) }) {
                            Text(action.label)
                                .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                                .padding(.horizontal, 14).frame(minHeight: 36)
                                .overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1))
                        }
                        .accessibilityIdentifier("advisorAction_\(action.label)")
                    }
                }
            }
            .homeCard()
        }
    }

    private func performAdvisorAction(_ id: AdvisorActionId) {
        switch id {
        case .takeBreak, .fiveMinReset:
            WellbeingActions.takeBreak(wellbeingStore: wellbeingStore, rewardStore: rewardStore)
            refresh()
        case .dismiss:
            advisorDismissed = true
        }
    }

    // MARK: - Four feature cards

    private var featureItems: [HomeFeatureCard] {
        [
            HomeFeatureCard(
                id: "advisor", icon: "sparkles", title: "Vision Advisor",
                description: "Personalised recommendations, learning support and smart guidance.",
                destination: .advisor, chip: nil
            ),
            HomeFeatureCard(
                id: "settings", icon: "gearshape", title: "Settings",
                description: "Customise your experience and manage your preferences.",
                destination: .settings, chip: nil
            ),
            HomeFeatureCard(
                id: "overview", icon: "calendar", title: "Today's Overview",
                description: "See your schedule, progress and important updates at a glance.",
                destination: .overview, chip: "\(overview.focusLabel) focus"
            ),
            HomeFeatureCard(
                id: "points", icon: "star.circle", title: "Vision Points",
                description: "Track your points, build healthy habits and explore available rewards.",
                destination: .points, chip: "\(pointsBalance) pts"
            ),
        ]
    }

    /// One row of four on wide layouts (iPad), a stacked list on phones.
    @ViewBuilder
    private var featureCards: some View {
        if sizeClass == .regular {
            HStack(alignment: .top, spacing: 14) {
                ForEach(featureItems) { featureTile($0) }
            }
        } else {
            VStack(spacing: 12) {
                ForEach(featureItems) { featureRow($0) }
            }
        }
    }

    private func featureIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 20, weight: .regular)).foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.10)))
            .accessibilityHidden(true)
    }

    private func chipView(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.12)))
    }

    private func featureRow(_ card: HomeFeatureCard) -> some View {
        Button(action: { onOpen(card.destination) }) {
            // Icon, chip and chevron share the top row, so the title and
            // description below get the card's full width instead of
            // being squeezed beside a chip.
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    featureIcon(card.icon)
                    Spacer(minLength: 8)
                    if let chip = card.chip { chipView(chip) }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(HomeTheme.textTertiary)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.title).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                    Text(card.description)
                        .font(.system(size: 13)).foregroundStyle(HomeTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .homeCard(padding: 14)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("homeCard_\(card.id)")
    }

    private func featureTile(_ card: HomeFeatureCard) -> some View {
        Button(action: { onOpen(card.destination) }) {
            VStack(alignment: .leading, spacing: 12) {
                featureIcon(card.icon)
                Text(card.title).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                Text(card.description)
                    .font(.system(size: 13)).foregroundStyle(HomeTheme.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if let chip = card.chip { chipView(chip) }
            }
            .frame(minHeight: 190, alignment: .topLeading)
            .homeCard(padding: 16)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("homeCard_\(card.id)")
    }

    // MARK: - Mode-dependent content

    private var modeContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            readinessCard
            if mode.isOffline { offlineSection } else { newsSection }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold)).tracking(0.4).foregroundStyle(HomeTheme.textSecondary)
    }

    /// Whole card opens VISION Ready; `.contain` keeps the percent / empty
    /// texts independently addressable instead of merging into one button.
    private var readinessCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.shield").font(.system(size: 16)).accessibilityHidden(true)
                Text("Offline readiness").font(.system(size: 15, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(HomeTheme.textTertiary)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.white)
            if let readiness, let percent = readiness.percent {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(percent)%").font(.system(size: 28, weight: .bold)).foregroundStyle(.white)
                        .accessibilityIdentifier("newTabReadinessPercent")
                    Text("\(readiness.savedCount) of \(readiness.bookmarkCount) bookmarks saved offline")
                        .font(.system(size: 13)).foregroundStyle(HomeTheme.textSecondary)
                }
                ProgressView(value: Double(percent), total: 100).tint(.white)
            } else {
                Text("Bookmark a page, then save it offline, to see how ready you are to browse without a connection.")
                    .font(.system(size: 13)).foregroundStyle(HomeTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("newTabReadinessEmpty")
            }
        }
        .homeCard()
        .contentShape(Rectangle())
        .onTapGesture { onOpen(.visionReady) }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
    }

    // Offline: only things that genuinely work without a connection.
    private var offlineSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Available offline")
            VStack(alignment: .leading, spacing: 0) {
                if savedPages.isEmpty {
                    Text("Nothing saved yet. Open a page and choose Save Offline to keep it here.")
                        .font(.system(size: 14)).foregroundStyle(HomeTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 4)
                        .accessibilityIdentifier("offlineSavedEmptyText")
                } else {
                    ForEach(Array(savedPages.enumerated()), id: \.element.id) { index, page in
                        Button(action: { onOpenSavedPage(URL(fileURLWithPath: page.contentPath)) }) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(page.title).font(.system(size: 15)).foregroundStyle(.white)
                                    .multilineTextAlignment(.leading).lineLimit(2)
                                Text(ByteCountFormatter.string(fromByteCount: page.sizeBytes, countStyle: .file))
                                    .font(.system(size: 12)).foregroundStyle(HomeTheme.textTertiary)
                            }
                            .padding(.vertical, 11)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .accessibilityIdentifier("offlineSavedPage_\(page.id)")
                        if index < savedPages.count - 1 {
                            Rectangle().fill(HomeTheme.divider).frame(height: 1)
                        }
                    }
                }
                Rectangle().fill(HomeTheme.divider).frame(height: 1).padding(.top, savedPages.isEmpty ? 8 : 0)
                Button(action: { onOpen(.offlineLibrary) }) {
                    HStack {
                        Text("Open Offline Library").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(HomeTheme.textTertiary)
                    }
                    .padding(.top, 12)
                }
                .accessibilityIdentifier("homeOpenOfflineLibrary")
            }
            .homeCard()

            sectionLabel("On-device tools")
            HStack(spacing: 10) {
                toolChip("Tasks", icon: "checklist", destination: .tasks, id: "homeTool_tasks")
                toolChip("Focus", icon: "scope", destination: .focus, id: "homeTool_focus")
                toolChip("Flashcards", icon: "rectangle.on.rectangle", destination: .flashcards, id: "homeTool_flashcards")
            }
        }
        // `.contain` keeps every button inside addressable by its own id — a bare
        // identifier on this container replaced all of theirs with "homeOfflineSection".
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("homeOfflineSection")
    }

    private func toolChip(_ title: String, icon: String, destination: HomeDestination, id: String) -> some View {
        Button(action: { onOpen(destination) }) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 18)).accessibilityHidden(true)
                Text(title).font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.black.opacity(0.42)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(HomeTheme.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    /// Real "Top Stories — BBC News" section (port of NewTabController.kt's
    /// refreshNews()/buildNewsCard()): a status line while loading or on
    /// failure, then up to 5 real headlines. Tapping one navigates the
    /// current tab in place to the article.
    @ViewBuilder
    private var newsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Top Stories — BBC News")
            switch newsStatus {
            case .loading:
                Text("Loading headlines…")
                    .font(.system(size: 13)).foregroundStyle(HomeTheme.textSecondary)
                    .accessibilityIdentifier("newsStatusText")
            case .empty:
                Text("Couldn't reach BBC News right now — check your connection and reopen a new tab.")
                    .font(.system(size: 13)).foregroundStyle(HomeTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("newsStatusText")
            case .loaded:
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(headlines.enumerated()), id: \.element.id) { index, headline in
                        Button(action: { onNavigate(headline.url) }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(headline.title)
                                    .font(.system(size: 15)).foregroundStyle(.white)
                                    .multilineTextAlignment(.leading)
                                Text(headline.source)
                                    .font(.system(size: 12)).foregroundStyle(HomeTheme.textTertiary)
                            }
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .accessibilityIdentifier("newsHeadline_\(headline.id)")
                        if index < headlines.count - 1 {
                            Rectangle().fill(HomeTheme.divider).frame(height: 1)
                        }
                    }
                }
                .homeCard(padding: 14)
                // `.contain` keeps each headline Button independently
                // addressable (SwiftUI otherwise merges them into one).
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("newsHeadlinesList")
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 12) {
            Rectangle().fill(HomeTheme.divider).frame(height: 1)
            VisionWordmark(height: 16)
            Text("For you to know the future, you need to have vision.")
                .font(.system(size: 12)).foregroundStyle(HomeTheme.textTertiary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("homeTagline")
        }
        .padding(.top, 6).padding(.bottom, 8)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Data

    private func refresh() {
        // Bookmarks are read only to compute Offline Readiness — not listed on
        // this screen, matching Android's NewTabController.kt.
        bookmarks = (try? bookmarkStore.list()) ?? []
        shortcuts = (try? shortcutStore.list()) ?? []
        savedPages = Array(((try? offlineStore.list()) ?? []).prefix(5))

        advisorDismissed = false
        advisorSuggestion = AdvisorLogic.getSuggestion(continuousSessionMs: WellbeingManager.shared.continuousSessionMs())

        let offlineItems = (try? offlineStore.list()) ?? []
        readiness = ReadinessLogic.compute(
            bookmarkUrls: bookmarks.map { $0.url },
            offlineUrls: offlineItems.map { $0.url },
            offlineCategories: offlineItems.map { $0.category }
        )

        overview = TodayOverviewSnapshot.current(wellbeingStore: wellbeingStore)
        pointsBalance = (try? rewardStore.availableBalance()) ?? 0
    }

    /// Real fetch, no caching — every time Home is shown while Online it
    /// refetches (matches Android/desktop; see NewsClient).
    private func refreshNews() async {
        newsStatus = .loading
        let fetched = await NewsClient.fetchTopHeadlines()
        headlines = fetched
        newsStatus = fetched.isEmpty ? .empty : .loaded
    }
}
