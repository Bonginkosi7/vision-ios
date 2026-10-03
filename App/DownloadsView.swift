import SwiftUI

/// Real downloads list — port of DownloadsActivity.kt. Each row shows the
/// real file state (progressing/completed/failed/cancelled) tracked by
/// DownloadStore, backed by a real WKDownload (see WebViewRepresentable).
///
/// DownloadsActivity.kt (and its activity_downloads.xml/item_download.xml
/// layouts) is a plain, pre-DesignSystem screen — no filter chips, no
/// per-row card/icon badge, no status pill, no fancy emoji empty state.
/// It's a flat list sitting on the theme's day/night window background,
/// with default (theme-adaptive) text colors, a single always-visible
/// delete icon button per row, and a plain one-line empty-state message.
/// This view intentionally mirrors that plainness rather than applying
/// DesignSystem.emptyState/bgCanvas, which belong to screens whose Android
/// counterpart actually opts into the reconstructed design system.
struct DownloadsView: View {
    @ObservedObject var downloadStore: DownloadStore
    @Environment(\.dismiss) private var dismiss

    @State private var records: [DownloadRecord] = []

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    // Matches activity_downloads.xml's emptyDownloadsText: a
                    // single plain, centered, 60%-opacity line of text — no
                    // emoji artwork, no title/subtitle split, no CTA button.
                    Text("No downloads yet.")
                        .multilineTextAlignment(.center)
                        .opacity(0.6)
                        .padding(32)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityIdentifier("emptyDownloadsState")
                } else {
                    List {
                        ForEach(records) { record in
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(record.filename)
                                        .font(.system(size: 15, weight: .bold))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Text(statusLine(record))
                                        .font(.system(size: 12))
                                        .opacity(0.65)
                                }
                                Spacer(minLength: 8)
                                Button(action: { remove(record) }) {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 40, height: 40)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Cancel")
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { if record.state == .completed { open(record) } }
                            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 8))
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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.backward")
                    }
                    .accessibilityIdentifier("downloadsBackButton")
                }
            }
        }
        .onAppear(perform: refresh)
    }

    /// Mirrors DownloadsAdapter.onBindViewHolder's `meta` line exactly:
    /// "$statusLabel · $sizeLabel · $timeLabel" — always all three parts,
    /// for every state (Android doesn't special-case completed-only).
    private func statusLine(_ record: DownloadRecord) -> String {
        let statusLabel: String
        switch record.state {
        case .progressing: statusLabel = "Downloading…"
        case .completed: statusLabel = "Done"
        case .cancelled: statusLabel = "Cancelled"
        case .failed: statusLabel = "Failed"
        }

        let sizeLabel: String
        if record.totalBytes > 0 {
            sizeLabel = "\(ByteCountFormatter.string(fromByteCount: record.receivedBytes, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: record.totalBytes, countStyle: .file))"
        } else {
            sizeLabel = ByteCountFormatter.string(fromByteCount: record.receivedBytes, countStyle: .file)
        }

        let timeFormatter = RelativeDateTimeFormatter()
        let timeLabel = timeFormatter.localizedString(for: record.completedAt ?? record.startedAt, relativeTo: Date())

        return "\(statusLabel) · \(sizeLabel) · \(timeLabel)"
    }

    private func refresh() {
        records = (try? downloadStore.list()) ?? []
    }

    private func remove(_ record: DownloadRecord) {
        try? downloadStore.remove(id: record.id)
        refresh()
    }

    private func open(_ record: DownloadRecord) {
        // Parity note: Android's openDownload() resolves a content:// URI via
        // DownloadManager and launches an ACTION_VIEW intent. iOS has no
        // equivalent file-opening plumbing wired up yet (no QuickLook/share
        // sheet presentation exists in this view or DownloadStore), so this
        // is left as a no-op tap target rather than invented here — that's a
        // functional gap, not a visual one, and out of this UI-only fix's scope.
    }
}
