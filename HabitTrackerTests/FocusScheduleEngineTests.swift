import XCTest
@testable import HabitTracker

final class FocusScheduleEngineTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    /// Only the hour/minute matter for `startTime`/`endTime`; the reference
    /// day is arbitrary.
    private func timeOnly(_ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: hour, minute: minute))!
    }

    private func makeSession(
        title: String = "Deep Work",
        start: (Int, Int) = (9, 0),
        end: (Int, Int) = (10, 0),
        rule: RecurrenceRule = .daily
    ) -> FocusSession {
        FocusSession(
            title: title,
            startTime: timeOnly(start.0, start.1),
            endTime: timeOnly(end.0, end.1),
            recurrenceRule: rule
        )
    }

    func testActiveWithinWindowOnScheduledDay() {
        let session = makeSession()
        let now = date(2026, 8, 3, 9, 30) // Monday
        XCTAssertTrue(FocusScheduleEngine.isActive(session, at: now, calendar: calendar))
    }

    func testNotActiveBeforeStart() {
        let session = makeSession()
        let now = date(2026, 8, 3, 8, 59)
        XCTAssertFalse(FocusScheduleEngine.isActive(session, at: now, calendar: calendar))
    }

    func testActiveExactlyAtStart() {
        let session = makeSession()
        let now = date(2026, 8, 3, 9, 0)
        XCTAssertTrue(FocusScheduleEngine.isActive(session, at: now, calendar: calendar))
    }

    func testNotActiveExactlyAtEnd() {
        let session = makeSession()
        let now = date(2026, 8, 3, 10, 0)
        XCTAssertFalse(FocusScheduleEngine.isActive(session, at: now, calendar: calendar))
    }

    func testNotActiveOnNonScheduledDay() {
        // 2026-08-03 is a Monday; the session only repeats on Fridays.
        let session = makeSession(rule: .weekdays([.friday]))
        let now = date(2026, 8, 3, 9, 30)
        XCTAssertFalse(FocusScheduleEngine.isActive(session, at: now, calendar: calendar))
    }

    func testCurrentlyActiveSessionReturnsFirstMatch() {
        let inactive = makeSession(title: "Inactive", start: (14, 0), end: (15, 0))
        let active = makeSession(title: "Active", start: (9, 0), end: (10, 0))
        let now = date(2026, 8, 3, 9, 30)

        let result = FocusScheduleEngine.currentlyActiveSession(in: [inactive, active], at: now, calendar: calendar)
        XCTAssertEqual(result?.title, "Active")
    }

    func testCurrentlyActiveSessionReturnsNilWhenNoneMatch() {
        let inactive = makeSession(title: "Inactive", start: (14, 0), end: (15, 0))
        let now = date(2026, 8, 3, 9, 30)

        XCTAssertNil(FocusScheduleEngine.currentlyActiveSession(in: [inactive], at: now, calendar: calendar))
    }
}
