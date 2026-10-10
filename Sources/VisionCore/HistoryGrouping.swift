import Foundation

/// Groups browsing history by when pages were really visited, using the
/// entry's own timestamp relative to `now` — nothing is hardcoded.
///
/// Buckets, newest first: Today, Yesterday, Earlier this week, Last week,
/// Earlier this month, then one section per "Month Year". "Week" follows the
/// supplied calendar's own first weekday.
public enum HistoryGrouping {
    enum Bucket {
        case today, yesterday, thisWeek, lastWeek, thisMonth, older
    }

    static func bucket(for date: Date, now: Date, calendar: Calendar) -> Bucket {
        let days = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)
        ).day ?? 0
        if days <= 0 { return .today }
        if days == 1 { return .yesterday }
        if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) { return .thisWeek }
        if let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now),
           calendar.isDate(date, equalTo: lastWeek, toGranularity: .weekOfYear) {
            return .lastWeek
        }
        if calendar.isDate(date, equalTo: now, toGranularity: .month) { return .thisMonth }
        return .older
    }

    /// The section heading a visit belongs under.
    public static func sectionLabel(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        switch bucket(for: date, now: now, calendar: calendar) {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .thisWeek: return "Earlier this week"
        case .lastWeek: return "Last week"
        case .thisMonth: return "Earlier this month"
        case .older: return format(date, "MMMM yyyy", calendar)
        }
    }

    /// The visit time shown on a row. The heading already says which day for
    /// Today/Yesterday, so those show only the clock time; older buckets add
    /// the weekday or the date so the row is still unambiguous.
    public static func timeLabel(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        switch bucket(for: date, now: now, calendar: calendar) {
        case .today, .yesterday: return format(date, "HH:mm", calendar)
        case .thisWeek, .lastWeek: return format(date, "EEE HH:mm", calendar)
        case .thisMonth, .older: return format(date, "d MMM, HH:mm", calendar)
        }
    }

    /// A self-contained time for places with no date heading (Downloads rows):
    /// "Today, 09:05", "Yesterday, 09:05", "Mon 09:05", "20 Sep, 09:05".
    public static func dateTimeLabel(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        switch bucket(for: date, now: now, calendar: calendar) {
        case .today: return "Today, " + format(date, "HH:mm", calendar)
        case .yesterday: return "Yesterday, " + format(date, "HH:mm", calendar)
        case .thisWeek, .lastWeek: return format(date, "EEE HH:mm", calendar)
        case .thisMonth, .older: return format(date, "d MMM, HH:mm", calendar)
        }
    }

    private static func format(_ date: Date, _ pattern: String, _ calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
