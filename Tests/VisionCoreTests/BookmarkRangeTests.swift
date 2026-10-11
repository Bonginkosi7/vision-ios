import XCTest
@testable import VisionCore

final class BookmarkRangeTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 2
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    // Friday 9 Oct 2026.
    private var now: Date { date(2026, 10, 9, 12) }

    private func has(_ range: BookmarkRange, _ d: Date) -> Bool {
        range.contains(d, now: now, calendar: calendar)
    }

    func test_todayAndYesterday() {
        XCTAssertTrue(has(.today, date(2026, 10, 9, 0)))
        XCTAssertFalse(has(.today, date(2026, 10, 8, 23)))
        XCTAssertTrue(has(.yesterday, date(2026, 10, 8, 23)))
        XCTAssertFalse(has(.yesterday, date(2026, 10, 9, 8)))
        XCTAssertFalse(has(.yesterday, date(2026, 10, 7, 8)))
    }

    func test_last7DaysIsTodayPlusSixBefore() {
        XCTAssertTrue(has(.last7, date(2026, 10, 3, 0)))
        XCTAssertFalse(has(.last7, date(2026, 10, 2, 23)))
    }

    func test_last30Days() {
        XCTAssertTrue(has(.last30, date(2026, 9, 10)))
        XCTAssertFalse(has(.last30, date(2026, 9, 9)))
    }

    func test_allKeepsEverything() {
        XCTAssertTrue(has(.all, date(2020, 1, 1)))
    }

    func test_groupsKeepOrderAndLabelsAndFilterByRange() {
        let items = [date(2026, 10, 9, 11), date(2026, 10, 9, 8), date(2026, 10, 8, 20), date(2026, 9, 20)]
        let all = DayGrouping.group(items, range: .all, now: now, calendar: calendar) { $0 }
        XCTAssertEqual(all.map(\.label), ["Today", "Yesterday", "September 2026"])
        XCTAssertEqual(all.map(\.items.count), [2, 1, 1])
        let week = DayGrouping.group(items, range: .last7, now: now, calendar: calendar) { $0 }
        XCTAssertEqual(week.map(\.label), ["Today", "Yesterday"])
    }

    func test_emptyInputGivesNoGroups() {
        XCTAssertTrue(DayGrouping.group([Date](), range: .all, now: now, calendar: calendar) { $0 }.isEmpty)
    }
}
