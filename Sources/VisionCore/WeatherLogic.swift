import Foundation

public struct Weather: Equatable, Sendable {
    public let temperatureC: Int
    public let weatherCode: Int
    public let locationLabel: String

    public init(temperatureC: Int, weatherCode: Int, locationLabel: String) {
        self.temperatureC = temperatureC
        self.weatherCode = weatherCode
        self.locationLabel = locationLabel
    }
}

/// Current weather for the New Tab page — the pure half of desktop's WeatherService.ts / Android's WeatherLogic.kt.
/// Open-Meteo (no API key) gives the conditions and BigDataCloud's free reverse-geocode gives a place name; this
/// file only builds the two addresses and reads their answers, so it can be tested without a network.
public enum WeatherLogic {
    public static func forecastURL(latitude: Double, longitude: Double) -> URL? {
        URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,weather_code")
    }

    public static func placeURL(latitude: Double, longitude: Double) -> URL? {
        URL(string: "https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=\(latitude)&longitude=\(longitude)&localityLanguage=en")
    }

    /// Real WMO weather codes (the open standard Open-Meteo returns) bucketed into a simple icon. Same buckets as desktop.
    public static func icon(forCode code: Int) -> String {
        switch code {
        case 0: return "☀️"
        case 1...3: return "🌤️"
        case 45, 48: return "🌫️"
        case 51...67: return "🌧️"
        case 71...77: return "❄️"
        case 80...82: return "🌦️"
        case 85...86: return "🌨️"
        case 95...: return "⛈️"
        default: return "🌡️"
        }
    }

    /// The conditions, from Open-Meteo's answer; nil when it isn't one. The place name is optional ("Your location" when missing).
    public static func parse(forecast: Data, place: Data?) -> Weather? {
        guard let json = try? JSONSerialization.jsonObject(with: forecast) as? [String: Any],
              let current = json["current"] as? [String: Any],
              let temperature = (current["temperature_2m"] as? NSNumber)?.doubleValue else { return nil }
        let code = (current["weather_code"] as? NSNumber)?.intValue ?? 0
        return Weather(temperatureC: Int(temperature.rounded()), weatherCode: code, locationLabel: placeLabel(from: place))
    }

    /// City, else locality, else region — whichever BigDataCloud filled in first.
    public static func placeLabel(from data: Data?) -> String {
        let fallback = "Your location"
        guard let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return fallback }
        for key in ["city", "locality", "principalSubdivision"] {
            if let value = (json[key] as? String)?.trimmingCharacters(in: .whitespaces), !value.isEmpty { return value }
        }
        return fallback
    }

    /// "☀️ 21° · Cape Town"
    public static func summary(_ weather: Weather) -> String {
        "\(icon(forCode: weather.weatherCode)) \(weather.temperatureC)° · \(weather.locationLabel)"
    }
}
