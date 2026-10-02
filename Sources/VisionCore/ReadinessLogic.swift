import Foundation

/// The result of `ReadinessLogic.compute` — percent of bookmarks also saved
/// offline, `nil` (not `0`) when there are no bookmarks yet so the UI can
/// show a real "nothing to measure yet" state instead of a fake 0%.
public struct ReadinessResult: Equatable {
    public let percent: Int?
    public let bookmarkCount: Int
    public let savedCount: Int
    public let byCategory: [String: Int]

    public init(percent: Int?, bookmarkCount: Int, savedCount: Int, byCategory: [String: Int]) {
        self.percent = percent
        self.bookmarkCount = bookmarkCount
        self.savedCount = savedCount
        self.byCategory = byCategory
    }
}

/// Pure calculation split out from the store reads so it's directly
/// testable — port of Android's `ReadinessLogic.kt`, itself matching
/// desktop's `OFFLINE_READINESS` handler (`src/main/ipc/ipcHandlers.ts`):
/// percent of bookmarks that are also saved offline.
public enum ReadinessLogic {
    public static func compute(bookmarkUrls: [String], offlineUrls: [String], offlineCategories: [String]) -> ReadinessResult {
        let savedUrls = Set(offlineUrls)
        let bookmarkCount = bookmarkUrls.count
        let savedCount = bookmarkUrls.filter { savedUrls.contains($0) }.count
        let percent: Int? = bookmarkCount == 0 ? nil : Int((Double(savedCount) / Double(bookmarkCount) * 100).rounded())
        var byCategory: [String: Int] = [:]
        for category in offlineCategories {
            byCategory[category, default: 0] += 1
        }
        return ReadinessResult(percent: percent, bookmarkCount: bookmarkCount, savedCount: savedCount, byCategory: byCategory)
    }
}
