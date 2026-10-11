import XCTest
@testable import VisionCore

final class WeatherLogicTests: XCTestCase {
    private func data(_ s: String) -> Data { Data(s.utf8) }

    func test_parsesTemperatureCodeAndPlace() throws {
        let forecast = data(#"{"current":{"temperature_2m":21.6,"weather_code":2}}"#)
        let place = data(#"{"city":"Cape Town","locality":"Central","principalSubdivision":"Western Cape"}"#)
        let w = try XCTUnwrap(WeatherLogic.parse(forecast: forecast, place: place))
        XCTAssertEqual(w, Weather(temperatureC: 22, weatherCode: 2, locationLabel: "Cape Town"))
        XCTAssertEqual(WeatherLogic.summary(w), "🌤️ 22° · Cape Town")
    }

    func test_placeFallsBackThroughLocalityRegionThenGeneric() {
        XCTAssertEqual(WeatherLogic.placeLabel(from: data(#"{"city":"","locality":"Soweto"}"#)), "Soweto")
        XCTAssertEqual(WeatherLogic.placeLabel(from: data(#"{"city":" ","principalSubdivision":"Gauteng"}"#)), "Gauteng")
        XCTAssertEqual(WeatherLogic.placeLabel(from: data("{}")), "Your location")
        XCTAssertEqual(WeatherLogic.placeLabel(from: nil), "Your location")
        XCTAssertEqual(WeatherLogic.placeLabel(from: data("nonsense")), "Your location")
    }

    func test_missingPlaceStillGivesWeather() {
        let w = WeatherLogic.parse(forecast: data(#"{"current":{"temperature_2m":-3.4}}"#), place: nil)
        XCTAssertEqual(w, Weather(temperatureC: -3, weatherCode: 0, locationLabel: "Your location"))
    }

    func test_rejectsAnswersWithoutATemperature() {
        XCTAssertNil(WeatherLogic.parse(forecast: data(#"{"current":{"weather_code":1}}"#), place: nil))
        XCTAssertNil(WeatherLogic.parse(forecast: data("{}"), place: nil))
        XCTAssertNil(WeatherLogic.parse(forecast: data("[]"), place: nil))
    }

    func test_iconBucketsMatchDesktop() {
        XCTAssertEqual(WeatherLogic.icon(forCode: 0), "☀️")
        XCTAssertEqual(WeatherLogic.icon(forCode: 3), "🌤️")
        XCTAssertEqual(WeatherLogic.icon(forCode: 48), "🌫️")
        XCTAssertEqual(WeatherLogic.icon(forCode: 61), "🌧️")
        XCTAssertEqual(WeatherLogic.icon(forCode: 75), "❄️")
        XCTAssertEqual(WeatherLogic.icon(forCode: 81), "🌦️")
        XCTAssertEqual(WeatherLogic.icon(forCode: 86), "🌨️")
        XCTAssertEqual(WeatherLogic.icon(forCode: 99), "⛈️")
        XCTAssertEqual(WeatherLogic.icon(forCode: 10), "🌡️")
    }

    func test_buildsBothAddresses() {
        XCTAssertEqual(WeatherLogic.forecastURL(latitude: -33.9, longitude: 18.4)?.host, "api.open-meteo.com")
        XCTAssertEqual(WeatherLogic.placeURL(latitude: -33.9, longitude: 18.4)?.host, "api.bigdatacloud.net")
    }
}

final class SitePermissionLogicTests: XCTestCase {
    func test_resolveAsksUntilEveryKindIsRemembered() {
        XCTAssertEqual(SitePermissionLogic.resolve(kinds: [.camera], remembered: { _ in nil }), .ask)
        XCTAssertEqual(SitePermissionLogic.resolve(kinds: [.camera, .microphone], remembered: { $0 == .camera ? true : nil }), .ask)
        XCTAssertEqual(SitePermissionLogic.resolve(kinds: [.camera, .microphone], remembered: { _ in true }), .grant)
    }

    func test_oneRememberedBlockBlocksTheWholeRequest() {
        XCTAssertEqual(SitePermissionLogic.resolve(kinds: [.camera, .microphone], remembered: { $0 == .microphone ? false : true }), .deny)
        XCTAssertEqual(SitePermissionLogic.resolve(kinds: [.camera, .microphone], remembered: { $0 == .microphone ? false : nil }), .deny)
    }

    func test_promptText() {
        XCTAssertEqual(SitePermissionLogic.promptText(host: "meet.example.com", kinds: [.camera]), "meet.example.com wants to use your camera.")
        XCTAssertEqual(SitePermissionLogic.promptText(host: "a.com", kinds: [.camera, .microphone]), "a.com wants to use your camera and microphone.")
    }

    func test_originDropsDefaultPortsAndRejectsNonWeb() {
        XCTAssertEqual(SitePermissionLogic.origin(scheme: "HTTPS", host: "Example.com", port: 443), "https://example.com")
        XCTAssertEqual(SitePermissionLogic.origin(scheme: "http", host: "example.com", port: 80), "http://example.com")
        XCTAssertEqual(SitePermissionLogic.origin(scheme: "https", host: "example.com", port: 0), "https://example.com")
        XCTAssertEqual(SitePermissionLogic.origin(scheme: "https", host: "localhost", port: 8443), "https://localhost:8443")
        XCTAssertNil(SitePermissionLogic.origin(scheme: "file", host: "x", port: 0))
        XCTAssertNil(SitePermissionLogic.origin(scheme: "https", host: "", port: 0))
    }
}
