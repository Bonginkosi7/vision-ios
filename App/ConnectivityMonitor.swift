import Foundation
import Network

/// Real, current network reachability — the iOS counterpart of
/// Android's ConnectivityUtil.kt (itself matching desktop's
/// getConnectionStatus().online), used only to show an honest online/
/// offline indicator, never to fabricate connectivity. Backed by
/// `NWPathMonitor`, the real system API for this on iOS (there is no
/// synchronous "is online right now" call the way Android's
/// ConnectivityManager.getNetworkCapabilities offers, so this stays
/// published/observed rather than a one-shot function).
@MainActor
final class ConnectivityMonitor: ObservableObject {
    static let shared = ConnectivityMonitor()

    @Published private(set) var isOnline: Bool = true
    /// True on mobile data / Personal Hotspot — used only to tell the user
    /// a big download will use their data bundle, never to block anything.
    @Published private(set) var isMetered: Bool = false

    private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            let metered = path.isExpensive
            Task { @MainActor [weak self] in
                self?.isOnline = online
                self?.isMetered = metered
            }
        }
        monitor.start(queue: DispatchQueue(label: "ConnectivityMonitor"))
    }
}
