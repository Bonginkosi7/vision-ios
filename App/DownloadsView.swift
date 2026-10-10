import SwiftUI
import VisionCore

/// Real downloads list — port of DownloadsActivity.kt. Each row shows the real
/// file state (progressing/completed/failed/cancelled) tracked by
/// DownloadStore, backed by a real WKDownload (see WebViewRepresentable).
///
/// The one icon on a row is the file's type (from its real name and MIME
/// type), because that tells you something true about the file. The source is
/// shown as its domain, with that site's real favicon only when one was
/// captured while browsing — the download's host isn't always a site you've
/// visited, so there's no icon rather than a guessed one.
struct DownloadsView: View {
    @ObservedObject var downloadStore: DownloadStore
    @Environment(\.dismiss) private var dismiss

    @State private var records: [DownloadRecord] = []

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    Text("No downloads yet.")
                        .font(.system(size: 15))
                        .foregroundStyle(DesignSystem.textMuted2)
                        .multilineTextAlignment(.center)
                        .padding(DesignSystem.Space.xxl)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityIdentifier("emptyDownloadsState")
                } else {
                    List {
                        ForEach(records) { record in
                            row(for: record)
                                .listRowBackground(DesignSystem.bgCanvas)
                                .listRowSeparatorTint(DesignSystem.borderCard)
                                .listRowInsets(EdgeInsets(top: DesignSystem.Space.m, leading: DesignSystem.Space.l, bottom: DesignSystem.Space.m, trailing: DesignSystem.Space.s))
                                .accessibilityIdentifier("downloadRow_\(record.id)")
                                .swipeActions {
                                    Button(role: .destructive) { remove(record) } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
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
            .visionScreen()
        }
        .onAppear(perform: refresh)
    }

    @ViewBuilder
    private func row(for record: DownloadRecord) -> some View {
        let source = URL(string: record.url)?.host.map(FaviconCache.key(forHost:))
        HStack(spacing: DesignSystem.Space.m) {
            Image(systemName: symbol(for: FileKind.kind(filename: record.filename, mimeType: record.mimeType)))
                .font(.system(size: 18))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: DesignSystem.Radius.control, style: .continuous).fill(DesignSystem.bgRaised))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(record.filename)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(statusLine(record))
                    .font(.system(size: 12))
                    .foregroundStyle(record.state == .failed ? DesignSystem.statusDangerText : DesignSystem.textMuted2)
                if record.state == .progressing, record.totalBytes > 0 {
                    ProgressView(value: Double(record.receivedBytes), total: Double(record.totalBytes))
                        .tint(.white)
                }
                if let source {
                    HStack(spacing: 6) {
                        if FaviconCache.image(forHost: source) != nil { FaviconView(host: source, size: 14) }
                        Text(source).font(.system(size: 12)).foregroundStyle(DesignSystem.textMuted2).lineLimit(1)
                    }
                }
            }
            Spacer(minLength: DesignSystem.Space.s)
            Button(action: { remove(record) }) {
                Image(systemName: "trash")
                    .font(.system(size: 15))
                    .foregroundStyle(DesignSystem.textMuted2)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel")
        }
        .contentShape(Rectangle())
        .onTapGesture { if record.state == .completed { open(record) } }
    }

    private func symbol(for kind: FileKind) -> String {
        switch kind {
        case .pdf: return "doc.richtext"
        case .image: return "photo"
        case .video: return "film"
        case .audio: return "music.note"
        case .archive: return "doc.zipper"
        case .document: return "doc.text"
        case .spreadsheet: return "tablecells"
        case .presentation: return "play.rectangle"
        case .text: return "doc.plaintext"
        case .other: return "doc"
        }
    }

    /// "<status> · <size> · <when>" — all three parts for every state, as
    /// DownloadsAdapter does on Android.
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

        let timeLabel = HistoryGrouping.dateTimeLabel(for: record.completedAt ?? record.startedAt)

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
        // Android's openDownload() resolves a content:// URI and launches an
        // ACTION_VIEW intent. iOS has no file-opening plumbing wired up yet (no
        // QuickLook/share sheet in this view or DownloadStore), so this stays a
        // no-op tap target rather than inventing one — a functional gap, not a
        // visual one, and out of this UI refinement's scope.
    }
}
