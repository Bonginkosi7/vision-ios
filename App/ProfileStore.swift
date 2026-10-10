import SwiftUI
import UIKit

/// The user's own profile: a name (used in the homepage greeting), a country, and an optional photo.
/// Everything is stored on this phone only — the photo as a small JPEG in Application Support, the
/// name and country in UserDefaults. Nothing is uploaded.
@MainActor
final class ProfileStore: ObservableObject {
    static let shared = ProfileStore()

    static let nameKey = "profile_display_name"
    static let countryKey = "profile_country"

    @Published private(set) var photo: UIImage?

    private init() {
        if let data = try? Data(contentsOf: Self.photoURL) { photo = UIImage(data: data) }
    }

    private static var photoURL: URL {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("profile-photo.jpg")
    }

    /// Shrinks the picked image (a profile photo never needs more than ~512pt) and saves it.
    func setPhoto(from data: Data) {
        guard let image = UIImage(data: data) else { return }
        let longest = max(image.size.width, image.size.height)
        let scale = longest > 512 ? 512 / longest : 1
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let jpeg = resized.jpegData(compressionQuality: 0.85) else { return }
        try? jpeg.write(to: Self.photoURL, options: .atomic)
        photo = resized
    }

    func removePhoto() {
        try? FileManager.default.removeItem(at: Self.photoURL)
        photo = nil
    }

    /// Clears the name, country and photo — nothing else.
    func reset() {
        removePhoto()
        UserDefaults.standard.removeObject(forKey: Self.nameKey)
        UserDefaults.standard.removeObject(forKey: Self.countryKey)
    }

    /// Country names in the user's own language, de-duplicated and sorted.
    static let countries: [String] = {
        var seen = Set<String>()
        return Locale.isoRegionCodes
            .compactMap { Locale.current.localizedString(forRegionCode: $0) }
            .filter { seen.insert($0).inserted }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }()

    /// First letters of the name (up to two), or "V" when there is none.
    static func initials(for name: String) -> String {
        let words = name.split(separator: " ").filter { !$0.isEmpty }
        guard let first = words.first else { return "V" }
        let letters = words.count > 1 ? [first.first!, words.last!.first!] : [first.first!]
        return String(letters).uppercased()
    }
}
