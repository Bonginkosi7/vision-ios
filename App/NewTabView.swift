import SwiftUI
import VisionCore

/// Real New Tab page — port of `NewTabController.kt`/desktop's
/// `newtab.ts`: a real time-of-day greeting, an "Ask VISION" box (real
/// URLs navigate, everything else routes to a real Ask VISION chat —
/// never a search-engine fallback, this box is not the address bar),
/// and the same real widget cards New Tab shares with their own full
/// screens elsewhere in this app — VISION Advisor (`AdvisorLogic`),
/// Offline Readiness (`VisionCore.ReadinessLogic`, same numbers as
/// VisionReadyView), Today's Overview (`WellbeingStore`/
/// `WellbeingManager`), and VISION Points (`RewardStore`/`RewardRules`,
/// same numbers as RewardsView) — plus the real bookmarks row.
///
/// Found via a cross-source design sweep as a major, previously-
/// undisclosed gap: this screen had stayed at its original Phase 1 cut
/// (bookmarks row only) ever since, even though three separate doc
/// comments elsewhere in this codebase (this file's own original one,
/// plus `WellbeingActions.swift`'s) already said these widgets belonged
/// here "in a later phase" that never actually arrived.
///
/// **Disclosed scope trim, not an oversight**: Android's real Weather
/// pill (`WeatherLogic`, a real location-based API call) and BBC World
/// News headline list (`NewsLogic`, a real feed fetch) are deliberately
/// NOT ported here — each is a genuine new external-API integration
/// (plus, for weather, a new location-permission flow) that deserves
/// its own real-source-verified phase rather than being rushed in
/// alongside everything else this sweep could close using only
/// infrastructure this app already has, tested, elsewhere. Full
/// onboarding is trimmed too — every destination it would point to is
/// already one tap away from the toolbar/menu.
///
/// The photo background (`bg_new_tab.jpg`, the exact same real asset
/// Android bundles at res/drawable-nodpi/bg_new_tab.jpg — not a
/// different stock photo standing in for it) and the real user-managed
/// Shortcuts row (`ShortcutStore`, a GRDB port of `ShortcutDbHelper.kt`,
/// icons sourced from the same real favicon service `FaviconLoader`
/// already uses elsewhere) were added in a later pass, closing what had
/// been this screen's two remaining disclosed trims.
struct NewTabView: View {
    @ObservedObject var bookmarkStore: BookmarkStore
    @ObservedObject var offlineStore: OfflineStore
    @ObservedObject var wellbeingStore: WellbeingStore
    @ObservedObject var rewardStore: RewardStore
    @ObservedObject var shortcutStore: ShortcutStore
    let onNavigate: (String) -> Void
    let onAskVision: (String) -> Void
    let onOpenVisionReady: () -> Void

    @State private var bookmarks: [Bookmark] = []
    @State private var shortcuts: [Shortcut] = []
    @State private var askText = ""
    @State private var showAddShortcut = false
    @State private var newShortcutTitle = ""
    @State private var newShortcutUrl = ""

    @State private var advisorSuggestion: AdvisorSuggestion?
    @State private var advisorDismissed = false

    @State private var readiness: ReadinessResult?

    @State private var focusLabel = "0m"
    @State private var breaksToday = 0
    @State private var sitesToday = 0
    @State private var tabsToday = 0

    @State private var pointsBalance = 0
    @State private var pointsLevel = 1
    @State private var pointsIntoLevel = 0
    @State private var latestReward: RewardEvent?

    var body: some View {
        ZStack {
            // bg_new_tab.jpg + bg_new_tab_scrim.xml: the real photo
            // Android shows behind this whole screen, with the same
            // top-to-bottom dark gradient scrim over it so white text
            // stays readable over any part of the image.
            GeometryReader { proxy in
                Image("NewTabBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
            .ignoresSafeArea()
            LinearGradient(
                colors: [
                    Color(hex: 0x050608).opacity(0.35),
                    Color(hex: 0x050608).opacity(0.55),
                    Color(hex: 0x050608).opacity(0.88),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // view_new_tab.xml shows the greeting ABOVE the Ask VISION
                // box (centered, 22sp) — pinned here, above askVisionBox, in
                // that same real order, rather than inside the ScrollView.
                Text(greeting)
                    .font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 20).padding(.top, 28)
                    .accessibilityIdentifier("newTabGreeting")

                // Deliberately pinned outside the ScrollView below, matching
                // NewTabController.kt's own fixed-position search row (it
                // never scrolls away with the widget cards) — found the hard
                // way via a real CI failure, not by design: with this box
                // inside the ScrollView, the keyboard's own scroll-into-view
                // adjustment on focus could shift the submit button out from
                // under an already-computed tap coordinate, the same real
                // "tap reports success, the real target never receives it"
                // class of bug Phase 11's Tutor screen hit for a different
                // reason (a horizontal ScrollView swallowing the gesture).
                askVisionBox
                    .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 2)

                // new_tab_ask_label — the "✨ Ask VISION" caption under the
                // input box, present in view_new_tab.xml but previously
                // missing from this port entirely.
                Text("✨ Ask VISION")
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.75))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24).padding(.bottom, 10)
                    .accessibilityIdentifier("newTabAskLabel")

                shortcutsRow
                    .padding(.top, 2).padding(.bottom, 4)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // view_new_tab.xml lays its four widget cards out as
                        // a real 2x2 grid (two MaterialCardViews per
                        // horizontal row, each layout_weight="1") — not a
                        // single-column stack. Row order (Advisor/Readiness,
                        // then Overview/Points) matches this port's existing
                        // top-to-bottom order exactly; only the grouping
                        // changes.
                        HStack(alignment: .top, spacing: 12) {
                            advisorCard.frame(maxWidth: .infinity)
                            readinessCard.frame(maxWidth: .infinity)
                        }
                        HStack(alignment: .top, spacing: 12) {
                            overviewCard.frame(maxWidth: .infinity)
                            pointsCard.frame(maxWidth: .infinity)
                        }

                        bookmarksSection
                    }
                    .padding(20)
                }
            }
        }
        .onAppear(perform: refresh)
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

    /// Horizontal row of real, user-managed shortcuts (`ShortcutStore`) —
    /// the SwiftUI counterpart of `refreshShortcuts()`/`buildShortcutTile()`
    /// in NewTabController.kt: one tile per real saved shortcut, a trailing
    /// "+" tile to add another, real favicons (not fabricated brand icons)
    /// via the same `FaviconLoader` the rest of this app already uses, and
    /// a long-press-to-remove affordance in place of Android's long-click
    /// popup menu.
    @ViewBuilder
    private var shortcutsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 4) {
                ForEach(shortcuts) { shortcut in
                    shortcutTile(shortcut)
                }
                addShortcutTile
            }
            .padding(.horizontal, 20)
        }
        .accessibilityIdentifier("newTabShortcutsRow")
    }

    @ViewBuilder
    private func shortcutTile(_ shortcut: Shortcut) -> some View {
        Button(action: { onNavigate(shortcut.url) }) {
            VStack(spacing: 4) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.14))
                    FaviconView(host: shortcutFaviconHost(shortcut.url))
                }
                .frame(width: 48, height: 48)
                Text(shortcut.title)
                    .font(.system(size: 11)).foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(width: 72)
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

    @ViewBuilder
    private var addShortcutTile: some View {
        Button(action: { showAddShortcut = true }) {
            VStack(spacing: 4) {
                Circle().fill(Color.white.opacity(0.14))
                    .frame(width: 48, height: 48)
                    .overlay(Image(systemName: "plus").foregroundStyle(.white))
                Text("Add").font(.system(size: 11)).foregroundStyle(.white)
            }
        }
        .accessibilityIdentifier("newTabAddShortcut")
    }

    /// web.whatsapp.com has no favicon of its own indexed by the lookup
    /// service (it 404s to a generic globe fallback) — whatsapp.com does
    /// have the real logo, same real host substitution NewTabController.kt
    /// makes for this one known case; every other URL still resolves from
    /// its own real host.
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

    /// Each of the four home-screen cards' title row: Android's
    /// NewTabCardTitle style (13sp bold white — a dedicated, smaller
    /// style than the 16sp DesignSystem.sectionLabel used on this app's
    /// other, full-screen activities) plus the same translucent "›"
    /// Android draws in the top-right corner of every one of these four
    /// cards, not just Offline Readiness.
    @ViewBuilder
    private func newTabCardHeader(_ title: String) -> some View {
        HStack {
            Text(title).font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
            Spacer()
            Text("›").font(.system(size: 18, weight: .bold)).foregroundStyle(.white.opacity(0.4))
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Good night"
        }
    }

    @ViewBuilder
    private var askVisionBox: some View {
        HStack(spacing: 8) {
            // new_tab_ask_hint is literally "Ask me anything" — not this
            // box's own invented placeholder copy.
            TextField("Ask me anything", text: $askText, onCommit: submitAsk)
                .textFieldStyle(.plain)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .frame(height: 56)
                .padding(.horizontal, 16)
                // bg_new_tab_input.xml: a near-pill (24dp radius on a
                // 56dp box) translucent dark fill with a translucent
                // white stroke — not this app's opaque, unbordered
                // bgCard, which belongs to the regular toolbar/widget
                // cards, not this photo-backed hero box.
                .background(RoundedRectangle(cornerRadius: 24).fill(Color.black.opacity(0.2)))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.25), lineWidth: 1))
                .foregroundStyle(.white)
                .accessibilityIdentifier("newTabSearchInput")
            Button(action: submitAsk) {
                // bg_avatar_circle.xml: a solid vision_purple circle
                // behind the send glyph — this had been a bare,
                // backgroundless icon.
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(DesignSystem.visionPurple))
            }
            .accessibilityIdentifier("newTabAskSubmit")
        }
    }

    @ViewBuilder
    private var advisorCard: some View {
        DesignSystem.card {
            newTabCardHeader("VISION Advisor")
                .accessibilityIdentifier("advisorCardTitle")
            if let advisorSuggestion, !advisorDismissed {
                Text(advisorSuggestion.message)
                    .font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                    .padding(.top, 8)
                    .accessibilityIdentifier("advisorMessage")
                HStack(spacing: 8) {
                    ForEach(advisorSuggestion.actions, id: \.label) { action in
                        Button(action.label) { performAdvisorAction(action.id) }
                            .font(.system(size: 12, weight: .bold))
                            .accessibilityIdentifier("advisorAction_\(action.label)")
                    }
                }
                .padding(.top, 8)
            } else {
                Text("You're on track — nothing needs your attention right now.")
                    .font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                    .padding(.top, 8)
                    .accessibilityIdentifier("advisorMessage")
            }
        }
    }

    @ViewBuilder
    private var readinessCard: some View {
        DesignSystem.card {
            Button(action: onOpenVisionReady) {
                newTabCardHeader("Offline Readiness")
            }
            if let readiness, let percent = readiness.percent {
                HStack(alignment: .bottom, spacing: 6) {
                    Text("\(percent)%").font(.system(size: 26, weight: .bold)).foregroundStyle(.white)
                        .accessibilityIdentifier("newTabReadinessPercent")
                    Text("of bookmarks saved offline").font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                }
                .padding(.top, 10)
                Text("🔖 \(readiness.savedCount) of \(readiness.bookmarkCount) bookmarks saved offline")
                    .font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2)
                    .padding(.top, 10)
            } else {
                Text("Bookmark a page, then save it offline, to see how ready you are to browse without a connection.")
                    .font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                    .padding(.top, 10)
                    .accessibilityIdentifier("newTabReadinessEmpty")
            }
        }
    }

    @ViewBuilder
    private var overviewCard: some View {
        DesignSystem.card {
            newTabCardHeader("Today's Overview")
            VStack(alignment: .leading, spacing: 6) {
                overviewStatRow(color: DesignSystem.visionPurple, label: "Focus time", value: focusLabel)
                overviewStatRow(color: DesignSystem.statusSuccess, label: "Breaks", value: "\(breaksToday)")
                overviewStatRow(color: DesignSystem.statDotOrange, label: "Sites", value: "\(sitesToday)")
                overviewStatRow(color: DesignSystem.visionBlue, label: "Tabs", value: "\(tabsToday)")
            }
            .padding(.top, 10)
            Text(breaksToday > 0 ? "💡 Nice, you've taken a real break today." : "💡 No breaks logged yet today.")
                .font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2)
                .padding(.top, 10)
                .accessibilityIdentifier("newTabOverviewNote")
        }
    }

    @ViewBuilder
    private func overviewStatRow(color: Color, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(label): \(value)").font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
        }
    }

    @ViewBuilder
    private var pointsCard: some View {
        DesignSystem.card {
            newTabCardHeader("VISION Points")
            Text("\(pointsBalance)").font(.system(size: 26, weight: .bold)).foregroundStyle(.white)
                .padding(.top, 10)
                .accessibilityIdentifier("newTabPointsBalance")
            Text("Level \(pointsLevel) — \(RewardRules.levelName(pointsLevel))")
                .font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
            Text("\(pointsIntoLevel) / \(RewardRules.levelSize) to next level")
                .font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2)
                .padding(.top, 4)
            if let latestReward {
                Text("🔖 \(latestReward.note) +\(latestReward.points)")
                    .font(.system(size: 12)).foregroundStyle(DesignSystem.statusSuccess)
                    .padding(.horizontal, 8).padding(.vertical, 6)
                    .background(Capsule().fill(DesignSystem.statusSuccess.opacity(0.1)))
                    .padding(.top, 10)
                    .accessibilityIdentifier("newTabLatestReward")
            } else {
                Text("No real points earned yet — browse, focus, and study to start earning.")
                    .font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2)
                    .padding(.top, 10)
            }
        }
    }

    @ViewBuilder
    private var bookmarksSection: some View {
        DesignSystem.sectionLabel("Bookmarks")

        if bookmarks.isEmpty {
            DesignSystem.emptyState(
                emoji: "🔖",
                title: "No bookmarks yet",
                subtitle: "Tap the star in the address bar to save a page.",
                ctaText: "Got it",
                onCta: {}
            )
            .accessibilityIdentifier("emptyBookmarksState")
        } else {
            DesignSystem.card {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(bookmarks) { bookmark in
                        Button(action: { onNavigate(bookmark.url) }) {
                            DesignSystem.statRow(emoji: "🔖", label: bookmark.title, value: "")
                        }
                        .accessibilityIdentifier("bookmarkRow_\(bookmark.url)")
                    }
                }
                // Real bug found via a CI UI test failure, not
                // review: SwiftUI's default accessibility-element
                // merging collapsed each row's own Button (and its
                // "bookmarkRow_<url>" identifier) into this single
                // outer container — a captured accessibility-tree
                // dump on relaunch showed exactly one merged
                // Button, identifier 'bookmarksList', label
                // '🔖, Example Domain', with the real per-row
                // identifier gone. `.contain` tells SwiftUI to keep
                // each child independently accessible instead of
                // flattening them into one element.
                .accessibilityElement(children: .contain)
            }
            .accessibilityIdentifier("bookmarksList")
        }
    }

    private func refresh() {
        bookmarks = (try? bookmarkStore.list()) ?? []
        shortcuts = (try? shortcutStore.list()) ?? []

        advisorDismissed = false
        advisorSuggestion = AdvisorLogic.getSuggestion(continuousSessionMs: WellbeingManager.shared.continuousSessionMs())

        let bookmarkUrls = bookmarks.map { $0.url }
        let offlineItems = (try? offlineStore.list()) ?? []
        readiness = ReadinessLogic.compute(
            bookmarkUrls: bookmarkUrls,
            offlineUrls: offlineItems.map { $0.url },
            offlineCategories: offlineItems.map { $0.category }
        )

        let ms = WellbeingManager.shared.continuousSessionMs()
        let totalMinutes = Int(ms / 60_000)
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        focusLabel = h > 0 ? "\(h)h \(m)m" : "\(m)m"
        breaksToday = (try? wellbeingStore.breaksToday()) ?? 0
        sitesToday = (try? wellbeingStore.distinctSitesToday()) ?? 0
        tabsToday = WellbeingManager.shared.tabsOpenedToday()

        let total = (try? rewardStore.total()) ?? 0
        pointsBalance = (try? rewardStore.availableBalance()) ?? 0
        pointsLevel = total / RewardRules.levelSize + 1
        pointsIntoLevel = total % RewardRules.levelSize
        latestReward = (try? rewardStore.recent(limit: 1))?.first
    }

    /// Real URL/domain -> navigate, exactly like the address bar.
    /// Anything else -> Ask VISION — this box is not the address bar,
    /// even though it accepts URLs too. Direct port of
    /// NewTabController.kt's own submitAsk().
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

    private func performAdvisorAction(_ id: AdvisorActionId) {
        switch id {
        case .takeBreak, .fiveMinReset:
            WellbeingActions.takeBreak(wellbeingStore: wellbeingStore, rewardStore: rewardStore)
            refresh()
        case .dismiss:
            advisorDismissed = true
        }
    }
}
