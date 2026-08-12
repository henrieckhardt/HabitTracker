import XCTest
@testable import HabitTracker

final class FocusStatsEngineTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.firstWeekday = 2 // Monday
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func closedRun(startedAt: Date, endedAt: Date) -> FocusRun {
        let run = FocusRun(sessionID: UUID(), sessionTitle: "Deep Work", startedAt: startedAt, plannedEnd: endedAt)
        run.endedAt = endedAt
        return run
    }

    func testOvernightRunIsClippedAcrossBothDays() {
        // 23:30 on the 3rd through 00:30 on the 4th — 30 min should count
        // toward each day, not the full 60 min toward whichever day it
        // started on.
        let run = closedRun(startedAt: date(2026, 8, 3, 23, 30), endedAt: date(2026, 8, 4, 0, 30))

        XCTAssertEqual(FocusStatsEngine.minutes(of: run, on: date(2026, 8, 3), calendar: calendar), 30)
        XCTAssertEqual(FocusStatsEngine.minutes(of: run, on: date(2026, 8, 4), calendar: calendar), 30)
        XCTAssertEqual(FocusStatsEngine.minutes(of: run, on: date(2026, 8, 2), calendar: calendar), 0)
    }

    func testOpenRunCountsUpToNowNotPlannedEnd() {
        let run = FocusRun(
            sessionID: UUID(),
            sessionTitle: "Deep Work",
            startedAt: date(2026, 8, 3, 9, 0),
            plannedEnd: date(2026, 8, 3, 10, 0)
        ) // endedAt left nil — still open
        let now = date(2026, 8, 3, 9, 20)

        XCTAssertEqual(FocusStatsEngine.minutes(of: run, on: date(2026, 8, 3), calendar: calendar, now: now), 20)
    }

    func testOpenRunNeverCountsPastItsPlannedEnd() {
        let run = FocusRun(
            sessionID: UUID(),
            sessionTitle: "Deep Work",
            startedAt: date(2026, 8, 3, 9, 0),
            plannedEnd: date(2026, 8, 3, 10, 0)
        )
        // `now` is an hour after plannedEnd, as if reconciliation just
        // hasn't run yet — the open run must still cap at plannedEnd, not
        // silently keep accruing.
        let now = date(2026, 8, 3, 11, 0)

        XCTAssertEqual(FocusStatsEngine.minutes(of: run, on: date(2026, 8, 3), calendar: calendar, now: now), 60)
    }

    func testWeekMinutesRespectsFirstWeekday() {
        // 2026-08-03 is a Monday. With firstWeekday = Monday, the week is
        // Aug 3–9; a run on the preceding Sunday (Aug 2) must not count.
        let sundayRun = closedRun(startedAt: date(2026, 8, 2, 9, 0), endedAt: date(2026, 8, 2, 9, 30))
        let mondayRun = closedRun(startedAt: date(2026, 8, 3, 9, 0), endedAt: date(2026, 8, 3, 9, 45))

        let total = FocusStatsEngine.weekMinutes([sundayRun, mondayRun], containing: date(2026, 8, 3), calendar: calendar)

        XCTAssertEqual(total, 45)
    }

    func testOutcomesSplitsCompletedFromEndedEarly() {
        let completed = closedRun(startedAt: date(2026, 8, 3, 9, 0), endedAt: date(2026, 8, 3, 9, 30))
        let endedEarly = closedRun(startedAt: date(2026, 8, 3, 9, 0), endedAt: date(2026, 8, 3, 9, 10))
        endedEarly.wasEndedEarly = true
        let stillOpen = FocusRun(
            sessionID: UUID(),
            sessionTitle: "Deep Work",
            startedAt: date(2026, 8, 3, 9, 0),
            plannedEnd: date(2026, 8, 3, 9, 30)
        )

        let outcomes = FocusStatsEngine.outcomes([completed, endedEarly, stillOpen])

        XCTAssertEqual(outcomes.completed, 1)
        XCTAssertEqual(outcomes.endedEarly, 1)
    }

    func testEmptyInputProducesZeroEverywhere() {
        XCTAssertEqual(FocusStatsEngine.minutes(in: [], on: date(2026, 8, 3), calendar: calendar), 0)
        XCTAssertEqual(FocusStatsEngine.weekMinutes([], containing: date(2026, 8, 3), calendar: calendar), 0)
        XCTAssertTrue(FocusStatsEngine.minutesPerDay([], in: calendar.dateInterval(of: .weekOfYear, for: date(2026, 8, 3))!, calendar: calendar).allSatisfy { $0.minutes == 0 })
        let outcomes = FocusStatsEngine.outcomes([])
        XCTAssertEqual(outcomes.completed, 0)
        XCTAssertEqual(outcomes.endedEarly, 0)
        XCTAssertEqual(FocusStatsEngine.minutes([], forHabit: UUID()), 0)
    }

    func testMinutesForHabitOnlyCountsLinkedRuns() {
        let habitID = UUID()
        let linked = closedRun(startedAt: date(2026, 8, 3, 9, 0), endedAt: date(2026, 8, 3, 9, 25))
        linked.linkedHabitID = habitID
        let unlinked = closedRun(startedAt: date(2026, 8, 3, 10, 0), endedAt: date(2026, 8, 3, 10, 40))

        XCTAssertEqual(FocusStatsEngine.minutes([linked, unlinked], forHabit: habitID), 25)
    }
}
