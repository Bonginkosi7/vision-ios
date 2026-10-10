import SwiftUI

/// The same four real numbers the old homepage "Today's Overview" card showed
/// inline (focus time, breaks, sites, tabs), read from the same stores.
struct TodayOverviewSnapshot {
    let focusLabel: String
    let breaks: Int
    let sites: Int
    let tabs: Int

    @MainActor
    static func current(wellbeingStore: WellbeingStore) -> TodayOverviewSnapshot {
        let totalMinutes = Int(WellbeingManager.shared.continuousSessionMs() / 60_000)
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return TodayOverviewSnapshot(
            focusLabel: h > 0 ? "\(h)h \(m)m" : "\(m)m",
            breaks: (try? wellbeingStore.breaksToday()) ?? 0,
            sites: (try? wellbeingStore.distinctSitesToday()) ?? 0,
            tabs: WellbeingManager.shared.tabsOpenedToday()
        )
    }
}

/// Where the homepage's Today's Overview card goes. There was never a
/// dedicated overview screen on any platform — the overview only ever lived
/// inline on the new-tab page — so this presents that same existing content
/// (no new data, no new logic) in a sheet.
struct TodayOverviewView: View {
    @ObservedObject var wellbeingStore: WellbeingStore
    @Environment(\.dismiss) private var dismiss
    @State private var snapshot = TodayOverviewSnapshot(focusLabel: "0m", breaks: 0, sites: 0, tabs: 0)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Space.l) {
                    DesignSystem.card {
                        VStack(spacing: 0) {
                            DesignSystem.statRow(label: "Focus time", value: snapshot.focusLabel)
                            DesignSystem.divider()
                            DesignSystem.statRow(label: "Breaks today", value: "\(snapshot.breaks)")
                            DesignSystem.divider()
                            DesignSystem.statRow(label: "Sites visited today", value: "\(snapshot.sites)")
                            DesignSystem.divider()
                            DesignSystem.statRow(label: "Tabs opened today", value: "\(snapshot.tabs)")
                        }
                    }
                    Text(snapshot.breaks > 0 ? "Nice, you've taken a real break today." : "No breaks logged yet today.")
                        .font(.system(size: 14)).foregroundStyle(DesignSystem.textMuted2)
                        .accessibilityIdentifier("newTabOverviewNote")
                }
                .padding(DesignSystem.Space.xl)
            }
            .background(DesignSystem.bgCanvas.ignoresSafeArea())
            .navigationTitle("Today's Overview")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear { snapshot = TodayOverviewSnapshot.current(wellbeingStore: wellbeingStore) }
    }
}
