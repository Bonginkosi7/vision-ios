import Foundation

/// The quick time ranges on the Bookmarks screen — the same set the desktop
/// Bookmarks and History pages offer. Days are whole calendar days relative to
/// `now`, so "Last 7 days" means today plus the six days before it.
public enum BookmarkRange: String, CaseIterable, Sendable {
    case all, today, yesterday, last7, last30

    public var title: String {
        switch self {
        case .all: return "All"
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .last7: return "Last 7 days"
        case .last30: return "Last 30 days"
        }
    }

    public func contains(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        let days = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)
        ).day ?? 0
        switch self {
        case .all: return true
        case .today: return days <= 0
        case .yesterday: return days == 1
        case .last7: return days < 7
        case .last30: return days < 30
        }
    }

    /// Sentence for the empty state when a range has no bookmarks.
    public var emptyText: String {
        switch self {
        case .all: return "No bookmarks yet — tap the star on any page to save it."
        case .today: return "Nothing bookmarked today."
        case .yesterday: return "Nothing bookmarked yesterday."
        case .last7: return "Nothing bookmarked in the last 7 days."
        case .last30: return "Nothing bookmarked in the last 30 days."
        }
    }
}

/// One day-heading with the items saved under it.
public struct DatedGroup<Item>: Sendable where Item: Sendable {
    public let label: String
    public let items: [Item]
}

public enum DayGrouping {
    /// Keeps `items` that fall inside `range`, then collects contiguous runs
    /// under the same heading (`HistoryGrouping.sectionLabel`) — valid because
    /// callers pass newest-first lists, like the History screen.
    public static func group<Item: Sendable>(
        _ items: [Item], range: BookmarkRange, now: Date = Date(),
        calendar: Calendar = .current, dateOf: (Item) -> Date
    ) -> [DatedGroup<Item>] {
        var result: [DatedGroup<Item>] = []
        var label: String?
        var run: [Item] = []
        for item in items where range.contains(dateOf(item), now: now, calendar: calendar) {
            let next = HistoryGrouping.sectionLabel(for: dateOf(item), now: now, calendar: calendar)
            if next != label {
                if let label { result.append(DatedGroup(label: label, items: run)) }
                label = next
                run = [item]
            } else {
                run.append(item)
            }
        }
        if let label { result.append(DatedGroup(label: label, items: run)) }
        return result
    }
}
