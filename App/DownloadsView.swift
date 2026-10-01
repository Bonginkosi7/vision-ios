import SwiftUI

/// Real downloads list — port of DownloadsActivity.kt. Each row shows the
/// real file state (progressing/completed/failed/cancelled) tracked by
/// DownloadStore, backed by a real WKDownload (see WebViewRepresentable).
struct DownloadsView: View {
    @ObservedObject var downloadStore: DownloadStore
    @Environment(\.dismiss) private var dismiss

    @State private var records: [DownloadRecord] = []

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    DesignSystem.emptyState(
                        emoji: "⬇️",
                        title: "No downloads yet",
                        subtitle: "Files you download will show up here.",
                        ctaText: "Got it",
                        onCta: { dismiss() }
                    )
                    .accessibilityIdentifier("emptyDownloadsState")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DesignSystem.bgCanvas)
                } else {
                    List {
                        ForEach(records) { record in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.filename).foregroundStyle(.white).lineLimit(1)
                                Text(statusLine(record)).font(.caption).foregroundStyle(DesignSystem.textMuted2)
                            }
                            .accessibilityIdentifier("downloadRow_\(record.id)")
                            .swipeActions {
                                Button(role: .destructive) { remove(record) } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .accessibilityIdentifier("downloadsList")
                }
            }
            .navigationTitle("Downloads")
        }
        .onAppear(perform: refresh)
    }

    private func statusLine(_ record: DownloadRecord) -> String {
        switch record.state {
        case .progressing: return "Downloading…"
        case .completed: return "\(ByteCountFormatter.string(fromByteCount: record.receivedBytes, countStyle: .file)) · Done"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }

    private func refresh() {
        records = (try? downloadStore.list()) ?? []
    }

    private func remove(_ record: DownloadRecord) {
        try? downloadStore.remove(id: record.id)
        refresh()
    }
}
