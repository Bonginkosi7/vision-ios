import XCTest
@testable import VisionCore

final class HistoryGroupingTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 2 // Monday
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9, _ min: Int = 5) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    // "Now" is Friday 9 Oct 2026, 12:00 UTC.
    private var now: Date { date(2026, 10, 9, 12, 0) }

    private func label(_ d: Date, now: Date? = nil) -> String {
        HistoryGrouping.sectionLabel(for: d, now: now ?? self.now, calendar: calendar)
    }

    func test_sameDayIsToday() {
        XCTAssertEqual(label(date(2026, 10, 9, 0, 1)), "Today")
        XCTAssertEqual(label(date(2026, 10, 9, 11, 59)), "Today")
    }

    func test_previousDayIsYesterday() {
        XCTAssertEqual(label(date(2026, 10, 8, 23, 59)), "Yesterday")
    }

    func test_earlierInTheSameCalendarWeek() {
        XCTAssertEqual(label(date(2026, 10, 5)), "Earlier this week") // Monday
    }

    func test_thePreviousCalendarWeek() {
        XCTAssertEqual(label(date(2026, 10, 1)), "Last week") // Thursday of the week before
    }

    func test_earlierInTheSameMonthBeyondLastWeek() {
        let lateOctober = date(2026, 10, 29, 12, 0)
        XCTAssertEqual(label(date(2026, 10, 2), now: lateOctober), "Earlier this month")
    }

    func test_olderMonthsGetMonthAndYearHeadings() {
        XCTAssertEqual(label(date(2026, 9, 20)), "September 2026")
        XCTAssertEqual(label(date(2025, 12, 15)), "December 2025")
    }

    func test_aTimestampSlightlyInTheFutureStillFilesUnderToday() {
        XCTAssertEqual(label(date(2026, 10, 9, 12, 30)), "Today")
    }

    func test_timeLabelsFollowTheBucket() {
        func time(_ d: Date) -> String { HistoryGrouping.timeLabel(for: d, now: now, calendar: calendar) }
        XCTAssertEqual(time(date(2026, 10, 9)), "09:05")
        XCTAssertEqual(time(date(2026, 10, 8)), "09:05")
        XCTAssertEqual(time(date(2026, 10, 5)), "Mon 09:05")
        XCTAssertEqual(time(date(2026, 10, 1)), "Thu 09:05")
        XCTAssertEqual(time(date(2026, 9, 20)), "20 Sep, 09:05")
    }

    func test_dateTimeLabelsAreSelfContained() {
        func label(_ d: Date) -> String { HistoryGrouping.dateTimeLabel(for: d, now: now, calendar: calendar) }
        XCTAssertEqual(label(date(2026, 10, 9)), "Today, 09:05")
        XCTAssertEqual(label(date(2026, 10, 8)), "Yesterday, 09:05")
        XCTAssertEqual(label(date(2026, 10, 5)), "Mon 09:05")
        XCTAssertEqual(label(date(2026, 9, 20)), "20 Sep, 09:05")
    }

    func test_contiguousEntriesNewestFirstProduceNonRepeatingHeadings() {
        let visits = [date(2026, 10, 9), date(2026, 10, 8), date(2026, 10, 5), date(2026, 10, 1), date(2026, 9, 20), date(2026, 9, 2)]
        let labels = visits.map { label($0) }
        XCTAssertEqual(labels, ["Today", "Yesterday", "Earlier this week", "Last week", "September 2026", "September 2026"])
    }
}
