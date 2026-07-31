import XCTest
@testable import HabitTracker

final class RecurrenceEngineTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testDailyIsAlwaysScheduled() {
        let rule = RecurrenceRule.daily
        XCTAssertTrue(RecurrenceEngine.isScheduled(rule, on: date(2026, 7, 31), calendar: calendar))
        XCTAssertTrue(RecurrenceEngine.isScheduled(rule, on: date(2026, 1, 1), calendar: calendar))
    }

    func testWeeklySingleDay() {
        // 2026-08-01 is a Saturday.
        let rule = RecurrenceRule.weekdays([.saturday])
        XCTAssertTrue(RecurrenceEngine.isScheduled(rule, on: date(2026, 8, 1), calendar: calendar))
        XCTAssertFalse(RecurrenceEngine.isScheduled(rule, on: date(2026, 8, 2), calendar: calendar))
    }

    func testWeekdaysMultipleDays() {
        // Tue+Thu example: 2026-08-04 is Tuesday, 2026-08-06 is Thursday, 2026-08-05 is Wednesday.
        let rule = RecurrenceRule.weekdays([.tuesday, .thursday])
        XCTAssertTrue(RecurrenceEngine.isScheduled(rule, on: date(2026, 8, 4), calendar: calendar))
        XCTAssertTrue(RecurrenceEngine.isScheduled(rule, on: date(2026, 8, 6), calendar: calendar))
        XCTAssertFalse(RecurrenceEngine.isScheduled(rule, on: date(2026, 8, 5), calendar: calendar))
    }

    func testMonthlyOnSpecificDay() {
        let rule = RecurrenceRule.monthly(daysOfMonth: [1])
        XCTAssertTrue(RecurrenceEngine.isScheduled(rule, on: date(2026, 8, 1), calendar: calendar))
        XCTAssertFalse(RecurrenceEngine.isScheduled(rule, on: date(2026, 8, 2), calendar: calendar))
    }

    func testMonthlyDayThatDoesNotExistInEveryMonthIsSkippedNaturally() {
        // Day 31 simply never occurs in February.
        let rule = RecurrenceRule.monthly(daysOfMonth: [31])
        XCTAssertTrue(RecurrenceEngine.isScheduled(rule, on: date(2026, 1, 31), calendar: calendar))
        XCTAssertFalse(RecurrenceEngine.isScheduled(rule, on: date(2026, 2, 28), calendar: calendar))
        for day in 1...28 {
            XCTAssertFalse(RecurrenceEngine.isScheduled(rule, on: date(2026, 2, day), calendar: calendar))
        }
    }
}
