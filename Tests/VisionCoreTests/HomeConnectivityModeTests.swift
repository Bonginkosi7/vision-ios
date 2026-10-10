import XCTest
@testable import VisionCore

final class HomeConnectivityModeTests: XCTestCase {
    func test_deviceOnlineAndNoPreference_isOnline() {
        XCTAssertEqual(HomeConnectivityMode.resolve(deviceOnline: true, offlineModeEnabled: false), .online)
    }

    func test_deviceOnlineWithOfflineModeChosen_isOfflineByChoice() {
        XCTAssertEqual(HomeConnectivityMode.resolve(deviceOnline: true, offlineModeEnabled: true), .offlineByChoice)
    }

    func test_noConnectionIsAlwaysOffline_whateverThePreference() {
        XCTAssertEqual(HomeConnectivityMode.resolve(deviceOnline: false, offlineModeEnabled: false), .offlineNoConnection)
        XCTAssertEqual(HomeConnectivityMode.resolve(deviceOnline: false, offlineModeEnabled: true), .offlineNoConnection)
    }

    func test_neverClaimsOnlineWithoutARealConnection() {
        for preference in [true, false] {
            XCTAssertTrue(HomeConnectivityMode.resolve(deviceOnline: false, offlineModeEnabled: preference).isOffline)
        }
    }

    func test_canOnlySwitchToOnlineWhenTheDeviceHasAConnection() {
        XCTAssertTrue(HomeConnectivityMode.online.canSwitchToOnline)
        XCTAssertTrue(HomeConnectivityMode.offlineByChoice.canSwitchToOnline)
        XCTAssertFalse(HomeConnectivityMode.offlineNoConnection.canSwitchToOnline)
    }

    func test_statusTextDiffersPerModeAndOfflineByChoiceIsHonestAboutBrowsing() {
        let texts = [HomeConnectivityMode.online, .offlineByChoice, .offlineNoConnection].map(\.statusText)
        XCTAssertEqual(Set(texts).count, 3)
        XCTAssertTrue(HomeConnectivityMode.offlineByChoice.statusText.contains("still use your connection"))
    }
}
