import SwiftUI
import VisionCore

/// Real "is my offline setup actually ready" screen — port of
/// VisionReadyActivity.kt, itself the Android counterpart of desktop's
/// vision-ready page (`src/renderer/vision-ready/vision-ready.ts`): real
/// connectivity, the same Offline Readiness numbers as the New Tab widget
/// (percent of bookmarks also saved offline, real storage used against the
/// real configurable limit, a real per-category breakdown), plus honest
/// disabled states for the sections this port can't back with a real
/// capability yet.
///
/// Deliberately different from Android here, not a missed port: Android's
/// own "Keeping Pages Up to Date" card has a real `Switch` because Android
/// ships a real Smart Cache background-refresh worker
/// (`BackgroundRefreshScheduler`) to flip on. iOS has never had that worker
/// — disclosed as a scope trim as far back as the Phase 2 migration
/// comment in `AppDatabase.swift` — so a switch here would control nothing
/// real. This card instead states that honestly, the same way Sports (no
/// live data provider configured, on any platform) and Maps (not built on
/// iOS yet) are already honestly disabled below it.
struct VisionReadyView: View {
    @ObservedObject var bookmarkStore: BookmarkStore
    @ObservedObject var offlineStore: OfflineStore
    let onOpenOfflineFile: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var connectivity = ConnectivityMonitor.shared

    @State private var result: ReadinessResult?
    @State private var usedBytes: Int64 = 0
    @State private var showOfflineLibrary = false

    private static let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    connectivityRow
                    offlineReadinessCard
                    upToDateCard
                    sportsCard
                    mapsCard
                }
                .padding(16)
            }
            .background(DesignSystem.bgCanvas.ignoresSafeArea())
            .navigationTitle("VISION Ready")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear(perform: load)
        .sheet(isPresented: $showOfflineLibrary) {
            OfflineLibraryView(offlineStore: offlineStore, onOpen: onOpenOfflineFile)
        }
    }

    @ViewBuilder
    private var connectivityRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(connectivity.isOnline ? DesignSystem.statusSuccess : DesignSystem.textMuted2)
                .frame(width: 8, height: 8)
            Text(connectivity.isOnline ? "Online" : "Offline")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DesignSystem.textMuted2)
                .accessibilityIdentifier("visionReadyConnectivityLabel")
        }
    }

    @ViewBuilder
    private var offlineReadinessCard: some View {
        DesignSystem.card {
            Button(action: { showOfflineLibrary = true }) {
                HStack {
                    DesignSystem.iconBadge("☁️")
                    Text("Offline Readiness")
                        .font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                        .padding(.leading, 12)
                    Spacer()
                    Text("›").font(.system(size: 20)).foregroundStyle(DesignSystem.textMuted2)
                }
            }
            .accessibilityIdentifier("btnManageOfflineContent")

            if let result, let percent = result.percent {
                HStack(alignment: .bottom, spacing: 8) {
                    Text("\(percent)%").font(.system(size: 28, weight: .bold)).foregroundStyle(.white)
                    Text("of bookmarks saved offline").font(.system(size: 14)).foregroundStyle(DesignSystem.textMuted2)
                }
                .padding(.top, 16)
                .accessibilityIdentifier("visionReadyPercent")

                ProgressView(value: Double(percent), total: 100)
                    .tint(DesignSystem.visionBlue)
                    .padding(.top, 12)

                HStack(spacing: 24) {
                    statColumn(value: "\(result.savedCount)", label: "of \(result.bookmarkCount) bookmarks saved offline")
                        .accessibilityIdentifier("visionReadyStatsSaved")
                    statColumn(
                        value: Self.byteCountFormatter.string(fromByteCount: usedBytes),
                        label: "used of \(AppSettings.offlineStorageLimitMb) MB storage limit"
                    )
                    .accessibilityIdentifier("visionReadyStatsStorage")
                }
                .padding(.top, 18)

                if !result.byCategory.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(result.byCategory.sorted(by: { $0.key < $1.key }), id: \.key) { category, count in
                            Text("\(category.capitalized): \(count)")
                                .font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                                .accessibilityIdentifier("visionReadyCategory_\(category)")
                        }
                    }
                    .padding(.top, 14)
                }
            } else {
                Text("Bookmark a page, then save it offline, to see how ready you are to browse without a connection.")
                    .font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                    .padding(.top, 14)
                    .accessibilityIdentifier("visionReadyEmptyReadiness")
            }
        }
    }

    @ViewBuilder
    private func statColumn(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
            Text(label).font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2)
        }
    }

    @ViewBuilder
    private var upToDateCard: some View {
        DesignSystem.card {
            HStack {
                DesignSystem.iconBadge("🔄")
                Text("Keeping Pages Up to Date")
                    .font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                    .padding(.leading, 12)
            }
            Text("Background refresh for saved pages isn't built on VISION for iOS yet — pages you save offline stay exactly as they were when you saved them. Reopen a page and save it again for a current copy.")
                .font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                .padding(.top, 12)
                .accessibilityIdentifier("visionReadyUpToDateBody")
        }
    }

    @ViewBuilder
    private var sportsCard: some View {
        DesignSystem.card {
            HStack {
                DesignSystem.iconBadge("🏆")
                Text("Sports").font(.system(size: 17, weight: .bold)).foregroundStyle(.white).padding(.leading, 12)
            }
            Text("Sports requires configuration — no live data provider is connected.")
                .font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                .padding(.top, 10)
                .accessibilityIdentifier("visionReadySportsBody")
        }
    }

    @ViewBuilder
    private var mapsCard: some View {
        DesignSystem.card {
            HStack {
                DesignSystem.iconBadge("📍")
                Text("Maps").font(.system(size: 17, weight: .bold)).foregroundStyle(.white).padding(.leading, 12)
            }
            Text("Offline maps aren't available on VISION for iOS yet.")
                .font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                .padding(.top, 10)
                .accessibilityIdentifier("visionReadyMapsBody")
        }
    }

    private func load() {
        let bookmarkUrls = ((try? bookmarkStore.list()) ?? []).map { $0.url }
        let offlineItems = (try? offlineStore.list()) ?? []
        result = ReadinessLogic.compute(
            bookmarkUrls: bookmarkUrls,
            offlineUrls: offlineItems.map { $0.url },
            offlineCategories: offlineItems.map { $0.category }
        )
        usedBytes = (try? offlineStore.totalSizeBytes()) ?? 0
    }
}
