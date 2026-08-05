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

    // MARK: - Overnight windows (end earlier than start, e.g. 22:00–08:00)

    func testOvernightActiveShortlyAfterStart() {
        let session = makeSession(start: (22, 0), end: (8, 0))
        let now = date(2026, 8, 3, 23, 0) // Monday night
        XCTAssertTrue(FocusScheduleEngine.isActive(session, at: now, calendar: calendar))
    }

    func testOvernightActiveExactlyAtStart() {
        let session = makeSession(start: (22, 0), end: (8, 0))
        let now = date(2026, 8, 3, 22, 0)
        XCTAssertTrue(FocusScheduleEngine.isActive(session, at: now, calendar: calendar))
    }

    func testOvernightActiveShortlyBeforeEndNextDay() {
        let session = makeSession(start: (22, 0), end: (8, 0))
        let now = date(2026, 8, 4, 3, 0) // Tuesday early morning, still "Monday's" window
        XCTAssertTrue(FocusScheduleEngine.isActive(session, at: now, calendar: calendar))
    }

    func testOvernightNotActiveExactlyAtEndNextDay() {
        let session = makeSession(start: (22, 0), end: (8, 0))
        let now = date(2026, 8, 4, 8, 0)
        XCTAssertFalse(FocusScheduleEngine.isActive(session, at: now, calendar: calendar))
    }

    func testOvernightNotActiveBetweenEndAndStart() {
        let session = makeSession(start: (22, 0), end: (8, 0))
        let now = date(2026, 8, 3, 12, 0) // Monday noon
        XCTAssertFalse(FocusScheduleEngine.isActive(session, at: now, calendar: calendar))
    }

    /// The pre-midnight segment of an overnight window must be checked
    /// against the day the window *started* on (Monday), not the calendar
    /// day `date` falls on (Tuesday) — this session only recurs Tuesdays,
    /// so a window that started Monday night must not be active.
    func testOvernightPreMidnightSegmentChecksStartDayNotCurrentDay() {
        let session = makeSession(start: (22, 0), end: (8, 0), rule: .weekdays([.tuesday]))
        let now = date(2026, 8, 4, 3, 0) // Tuesday 03:00 — window started Monday, not scheduled
        XCTAssertFalse(FocusScheduleEngine.isActive(session, at: now, calendar: calendar))
    }

    /// Same setup, but the window starts on a scheduled Tuesday night, so
    /// the pre-midnight segment on Wednesday morning should be active.
    func testOvernightPreMidnightSegmentActiveWhenStartDayWasScheduled() {
        let session = makeSession(start: (22, 0), end: (8, 0), rule: .weekdays([.tuesday]))
        let now = date(2026, 8, 5, 3, 0) // Wednesday 03:00 — window started Tuesday, scheduled
        XCTAssertTrue(FocusScheduleEngine.isActive(session, at: now, calendar: calendar))
    }

    func testZeroLengthWindowIsNeverActive() {
        let session = makeSession(start: (9, 0), end: (9, 0))
        let now = date(2026, 8, 3, 9, 0)
        XCTAssertFalse(FocusScheduleEngine.isActive(session, at: now, calendar: calendar))
    }

    // MARK: - On-demand sessions (manually started, fixed duration)

    private func makeOnDemandSession(activeUntil: Date?, pendingStart: Date? = nil) -> FocusSession {
        let session = FocusSession(
            title: "Deep Work",
            startTime: timeOnly(9, 0),
            endTime: timeOnly(10, 0),
            isOnDemand: true,
            durationMinutes: 60
        )
        session.activeUntil = activeUntil
        session.pendingStart = pendingStart
        return session
    }

    func testOnDemandActiveWhileBeforeActiveUntil() {
        let now = date(2026, 8, 3, 12, 0)
        let session = makeOnDemandSession(activeUntil: date(2026, 8, 3, 13, 0))
        XCTAssertTrue(FocusScheduleEngine.isActive(session, at: now, calendar: calendar))
    }

    func testOnDemandNotActiveExactlyAtActiveUntil() {
        let now = date(2026, 8, 3, 13, 0)
        let session = makeOnDemandSession(activeUntil: date(2026, 8, 3, 13, 0))
        XCTAssertFalse(FocusScheduleEngine.isActive(session, at: now, calendar: calendar))
    }

    func testOnDemandNotActiveAfterActiveUntil() {
        let now = date(2026, 8, 3, 14, 0)
        let session = makeOnDemandSession(activeUntil: date(2026, 8, 3, 13, 0))
        XCTAssertFalse(FocusScheduleEngine.isActive(session, at: now, calendar: calendar))
    }

    func testOnDemandNotActiveWhenNeverStarted() {
        let now = date(2026, 8, 3, 9, 30) // would be "active" for a scheduled 9-10 window
        let session = makeOnDemandSession(activeUntil: nil)
        XCTAssertFalse(FocusScheduleEngine.isActive(session, at: now, calendar: calendar))
    }

    // MARK: - On-demand sessions scheduled to start in the future ("Später starten")

    func testOnDemandNotActiveBeforePendingStart() {
        let now = date(2026, 8, 3, 12, 0)
        let session = makeOnDemandSession(activeUntil: date(2026, 8, 3, 13, 0), pendingStart: date(2026, 8, 3, 12, 30))
        XCTAssertFalse(FocusScheduleEngine.isActive(session, at: now, calendar: calendar))
    }

    func testOnDemandActiveExactlyAtPendingStart() {
        let now = date(2026, 8, 3, 12, 30)
        let session = makeOnDemandSession(activeUntil: date(2026, 8, 3, 13, 0), pendingStart: date(2026, 8, 3, 12, 30))
        XCTAssertTrue(FocusScheduleEngine.isActive(session, at: now, calendar: calendar))
    }

    func testOnDemandActiveAfterPendingStartPasses() {
        let now = date(2026, 8, 3, 12, 45)
        let session = makeOnDemandSession(activeUntil: date(2026, 8, 3, 13, 0), pendingStart: date(2026, 8, 3, 12, 30))
        XCTAssertTrue(FocusScheduleEngine.isActive(session, at: now, calendar: calendar))
    }

    func testOnDemandNotActiveAfterActiveUntilEvenWithPendingStartInPast() {
        let now = date(2026, 8, 3, 14, 0)
        let session = makeOnDemandSession(activeUntil: date(2026, 8, 3, 13, 0), pendingStart: date(2026, 8, 3, 12, 30))
        XCTAssertFalse(FocusScheduleEngine.isActive(session, at: now, calendar: calendar))
    }
}
