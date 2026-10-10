/// What the homepage's Online / Offline control should show and allow, derived
/// from two real inputs only: whether the device actually has a connection
/// (`ConnectivityMonitor`'s NWPathMonitor) and whether the user has chosen
/// Offline Mode (a persisted preference). Pure so the rules — especially
/// "never claim Online while the device has no connection" — are unit-tested.
///
/// Offline Mode on this app is a homepage-level choice: Home stops fetching
/// live content and shows what is saved on the device. It does not cut the
/// device's network, so the copy below says so rather than implying it does.
public enum HomeConnectivityMode: Equatable {
    case online
    case offlineByChoice
    case offlineNoConnection

    public static func resolve(deviceOnline: Bool, offlineModeEnabled: Bool) -> HomeConnectivityMode {
        if !deviceOnline { return .offlineNoConnection }
        return offlineModeEnabled ? .offlineByChoice : .online
    }

    public var isOffline: Bool { self != .online }

    /// The user can only go Online if the device really has a connection.
    public var canSwitchToOnline: Bool { self != .offlineNoConnection }

    public var statusText: String {
        switch self {
        case .online:
            return "Online — live headlines and web browsing are available."
        case .offlineByChoice:
            return "Offline Mode — Home shows saved content only. Web pages you open still use your connection."
        case .offlineNoConnection:
            return "No internet connection — showing what's saved on this device."
        }
    }

    /// Shown when the user taps Online but the device has no connection.
    public static let cannotGoOnlineExplanation =
        "This device has no internet connection, so Vision can't go online. Check Wi-Fi or mobile data — Online mode returns automatically once you're connected."
}
