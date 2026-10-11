import CoreLocation
import Foundation
import VisionCore

/// The New Tab weather pill's data: the device's approximate location (asked for only when the person taps
/// "Enable weather"), then current conditions from Open-Meteo and a place name from BigDataCloud. The coordinates go
/// to those two services and nowhere else (see the privacy screen); nothing is fetched until location is allowed.
@MainActor
final class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = WeatherService()

    enum State: Equatable {
        case needsPermission   // never asked: the pill offers "Enable weather"
        case loading
        case ready(Weather)
        case hidden            // location refused, or weather unavailable right now: show nothing rather than a placeholder
    }

    @Published private(set) var state: State = .hidden

    private let manager = CLLocationManager()
    private var lastFetch: Date?
    /// A reading from the last 20 minutes is shown as is, so opening New Tab doesn't refetch every time.
    private let freshFor: TimeInterval = 20 * 60

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Called whenever New Tab is shown with weather switched on.
    func refresh() {
        switch manager.authorizationStatus {
        case .notDetermined:
            state = .needsPermission
        case .denied, .restricted:
            state = .hidden
        default:
            if case .ready = state, let last = lastFetch, Date().timeIntervalSince(last) < freshFor { return }
            if case .ready = state {} else { state = .loading }
            manager.requestLocation()
        }
    }

    /// The person tapped "Enable weather".
    func requestPermission() {
        state = .loading
        manager.requestWhenInUseAuthorization()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways: self.manager.requestLocation()
            case .denied, .restricted: self.state = .hidden
            default: break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in await self.fetch(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in if case .loading = self.state { self.state = .hidden } }
    }

    private func fetch(latitude: Double, longitude: Double) async {
        guard let forecastURL = WeatherLogic.forecastURL(latitude: latitude, longitude: longitude),
              let placeURL = WeatherLogic.placeURL(latitude: latitude, longitude: longitude),
              let (forecast, _) = try? await URLSession.shared.data(from: forecastURL) else {
            if case .loading = state { state = .hidden }
            return
        }
        let place = try? await URLSession.shared.data(from: placeURL).0
        if let weather = WeatherLogic.parse(forecast: forecast, place: place) {
            state = .ready(weather)
            lastFetch = Date()
        } else if case .loading = state {
            state = .hidden
        }
    }
}
