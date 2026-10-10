import SwiftUI
import VisionCore

/// Real "is my offline setup actually ready" screen — port of
/// VisionReadyActivity.kt, itself the Android counterpart of desktop's
/// vision-ready page: real connectivity, the same Offline Readiness numbers as
/// the homepage card (percent of bookmarks also saved offline, real storage used
/// against the real configurable limit, a per-category breakdown), plus honest
/// "not available yet" notes for what this port can't back with a real
/// capability.
///
/// Deliberately different from Android, not a missed port: Android's "Keeping
/// Pages Up to Date" has a real `Switch` because it ships a Smart Cache
/// background-refresh worker to flip on. iOS never has — disclosed as a scope
/// trim since the Phase 2 migration comment in `AppDatabase.swift` — so a
/// switch here would control nothing. It states that plainly instead, like
/// Sports (no live data provider on any platform) and Maps (not built on iOS).
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
                VStack(alignment: .leading, spacing: DesignSystem.Space.l) {
                    connectivityRow
                    offlineReadinessCard
                    notAvailableCard
                }
                .padding(DesignSystem.Space.l)
            }
            .navigationTitle("VISION Ready")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .visionScreen()
        }
        .onAppear(perform: load)
        .sheet(isPresented: $showOfflineLibrary) {
            OfflineLibraryView(offlineStore: offlineStore, onOpen: onOpenOfflineFile)
        }
    }

    /// Green means online — the one place colour carries state here.
    private var connectivityRow: some View {
        HStack(spacing: DesignSystem.Space.s) {
            Circle()
                .fill(connectivity.isOnline ? DesignSystem.statusSuccess : DesignSystem.textMuted2)
                .frame(width: 8, height: 8)
            Text(connectivity.isOnline ? "Online" : "Offline")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DesignSystem.textMuted2)
                .accessibilityIdentifier("visionReadyConnectivityLabel")
        }
    }

    private var offlineReadinessCard: some View {
        DesignSystem.card {
            Text("Offline readiness")
                .font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)

            if let result, let percent = result.percent {
                HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Space.s) {
                    Text("\(percent)%")
                        .font(.system(size: 34, weight: .semibold)).foregroundStyle(.white)
                        .accessibilityIdentifier("visionReadyPercent")
                    Text("of bookmarks saved offline")
                        .font(.system(size: 14)).foregroundStyle(DesignSystem.textMuted2)
                }
                .padding(.top, DesignSystem.Space.m)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(DesignSystem.bgRaised)
                        Capsule().fill(Color.white)
                            .frame(width: geometry.size.width * CGFloat(percent) / 100)
                    }
                }
                .frame(height: 6)
                .padding(.top, DesignSystem.Space.m)

                HStack(alignment: .top, spacing: DesignSystem.Space.xl) {
                    statColumn(
                        value: "\(result.savedCount)", label: "of \(result.bookmarkCount) bookmarks saved offline",
                        valueId: "visionReadyStatsSaved"
                    )
                    statColumn(
                        value: Self.byteCountFormatter.string(fromByteCount: usedBytes),
                        label: "used of \(AppSettings.offlineStorageLimitMb) MB storage limit",
                        valueId: "visionReadyStatsStorage"
                    )
                }
                .padding(.top, DesignSystem.Space.l)

                if !result.byCategory.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.Space.xs) {
                        ForEach(result.byCategory.sorted(by: { $0.key < $1.key }), id: \.key) { category, count in
                            Text("\(category.capitalized): \(count)")
                                .font(.system(size: 13)).foregroundStyle(DesignSystem.textMuted2)
                                .accessibilityIdentifier("visionReadyCategory_\(category)")
                        }
                    }
                    .padding(.top, DesignSystem.Space.m)
                }
            } else {
                Text("Bookmark a page, then save it offline, to see how ready you are to browse without a connection.")
                    .font(.system(size: 14)).foregroundStyle(DesignSystem.textMuted2)
                    .padding(.top, DesignSystem.Space.s)
                    .accessibilityIdentifier("visionReadyEmptyReadiness")
            }

            // The one action on this card, shown whether or not there's
            // readiness data yet (as on Android).
            Button(action: { showOfflineLibrary = true }) {
                HStack {
                    Text("Manage offline content").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(DesignSystem.textMuted2)
                }
                .padding(.horizontal, DesignSystem.Space.l).frame(minHeight: 48)
                .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous).stroke(DesignSystem.borderCard, lineWidth: 1))
            }
            .padding(.top, DesignSystem.Space.l)
            .accessibilityIdentifier("btnManageOfflineContent")
        }
    }

    private func statColumn(value: String, label: String, valueId: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                .accessibilityIdentifier(valueId)
            Text(label).font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Three honest "not available on this build" notes in one quiet card,
    /// instead of three separate bordered cards.
    private var notAvailableCard: some View {
        DesignSystem.card {
            note(
                title: "Keeping pages up to date",
                body: "Background refresh for saved pages isn't built on VISION for iOS yet — pages you save offline stay exactly as they were when you saved them. Reopen a page and save it again for a current copy.",
                id: "visionReadyUpToDateBody"
            )
            DesignSystem.divider().padding(.vertical, DesignSystem.Space.m)
            note(
                title: "Sports",
                body: "Sports requires configuration — no live data provider is connected.",
                id: "visionReadySportsBody"
            )
            DesignSystem.divider().padding(.vertical, DesignSystem.Space.m)
            note(
                title: "Maps",
                body: "Offline maps aren't available on VISION for iOS yet.",
                id: "visionReadyMapsBody"
            )
        }
    }

    private func note(title: String, body: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Space.xs) {
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
            Text(body)
                .font(.system(size: 14)).foregroundStyle(DesignSystem.textMuted2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(id)
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
