import SwiftUI

/// Settings row: download, watch progress, or remove the on-device model.
struct OfflineModelRow: View {
    @ObservedObject private var manager = LocalModelManager.shared
    @ObservedObject private var connectivity = ConnectivityMonitor.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(LocalModelFile.displayName) · \(LocalModelFile.sizeLabel)")
                .font(.system(size: 15, weight: .semibold))
            switch manager.state {
            case .notDownloaded:
                Text(connectivity.isMetered
                     ? "Not downloaded. You're on mobile data — the download will use \(LocalModelFile.sizeLabel) of your bundle."
                     : "Not downloaded.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Download") { manager.start() }
                    .accessibilityIdentifier("offlineModelDownload")
            case .downloading(let progress):
                ProgressView(value: progress)
                Text("Downloading… \(Int(progress * 100))%")
                    .font(.footnote).foregroundStyle(.secondary)
                    .accessibilityIdentifier("offlineModelProgress")
                Button("Cancel") { manager.cancel() }
                    .accessibilityIdentifier("offlineModelCancel")
            case .ready:
                Text("Ready — Ask VISION can answer offline.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .accessibilityIdentifier("offlineModelReady")
                Button("Remove from this phone") { manager.remove() }
                    .accessibilityIdentifier("offlineModelRemove")
            case .failed(let message):
                Text(message).font(.footnote).foregroundStyle(.secondary)
                Button("Download") { manager.start() }
                    .accessibilityIdentifier("offlineModelDownload")
            }
        }
        .padding(.vertical, 4)
    }
}

/// One-time homepage prompt offering the offline model. The user chooses —
/// Wi-Fi or mobile data both work; on mobile data the card says so. "Not
/// now" hides it for good (Settings still has the download).
struct OfflineModelPromptCard: View {
    @ObservedObject private var manager = LocalModelManager.shared
    @ObservedObject private var connectivity = ConnectivityMonitor.shared
    @AppStorage("offline_model_prompt_dismissed") private var dismissed = false

    private var shouldShow: Bool {
        if dismissed { return false }
        switch manager.state {
        case .ready: return false
        default: return true
        }
    }

    var body: some View {
        if shouldShow {
            VStack(alignment: .leading, spacing: 10) {
                Text("Get offline Ask VISION")
                    .font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                switch manager.state {
                case .downloading(let progress):
                    ProgressView(value: progress).tint(.white)
                    Text("Downloading… \(Int(progress * 100))%")
                        .font(.system(size: 13)).foregroundStyle(HomeTheme.textSecondary)
                    Button("Cancel") { manager.cancel() }
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        .frame(minHeight: 44)
                case .failed(let message):
                    Text(message).font(.system(size: 13)).foregroundStyle(HomeTheme.textSecondary)
                    buttons
                default:
                    Text(connectivity.isMetered
                         ? "Ask questions with no internet. The \(LocalModelFile.sizeLabel) download will use your mobile data."
                         : "Ask questions with no internet. One-time \(LocalModelFile.sizeLabel) download, kept on your phone.")
                        .font(.system(size: 13)).foregroundStyle(HomeTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    buttons
                }
            }
            .homeCard(padding: 16)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("offlineModelPrompt")
        }
    }

    private var buttons: some View {
        HStack(spacing: 12) {
            Button(action: { manager.start() }) {
                Text("Download")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(.black)
                    .padding(.horizontal, 18).frame(minHeight: 44)
                    .background(Capsule().fill(Color.white))
            }
            .accessibilityIdentifier("offlineModelPromptDownload")
            Button("Not now") { dismissed = true }
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                .frame(minHeight: 44)
                .accessibilityIdentifier("offlineModelPromptDismiss")
        }
    }
}
