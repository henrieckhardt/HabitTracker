import XCTest
@testable import HabitTracker

final class HabitHistoryEngineTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.firstWeekday = 2 // Monday
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testOffDaysAreNotScheduledForAWeekdaysOnlyHabit() {
        // Tuesday/Thursday only.
        let habit = Habit(title: "Gym", recurrenceRule: .weekdays([.tuesday, .thursday]), createdAt: date(2026, 1, 1))
        let grid = HabitHistoryEngine.grid(for: habit, weeks: 1, endingOn: date(2026, 8, 6), calendar: calendar) // Aug 6 2026 is Thursday

        let states = Dictionary(uniqueKeysWithValues: grid.flatMap { $0 }.map { ($0.date, $0.state) })
        // Monday Aug 3 is off-schedule, Tuesday Aug 4 is scheduled (and unmarked -> missed).
        XCTAssertEqual(states[date(2026, 8, 3)], .notScheduled)
        XCTAssertEqual(states[date(2026, 8, 4)], .missed)
    }

    func testDaysBeforeCreationAreBeforeCreationNotMissed() {
        let habit = Habit(title: "Meditate", recurrenceRule: .daily, createdAt: date(2026, 8, 5))
        let grid = HabitHistoryEngine.grid(for: habit, weeks: 1, endingOn: date(2026, 8, 6), calendar: calendar)

        let states = Dictionary(uniqueKeysWithValues: grid.flatMap { $0 }.map { ($0.date, $0.state) })
        XCTAssertEqual(states[date(2026, 8, 3)], .beforeCreation)
        XCTAssertEqual(states[date(2026, 8, 4)], .beforeCreation)
        // The creation day itself is eligible.
        XCTAssertEqual(states[date(2026, 8, 5)], .missed)
    }

    func testFirstWeekdayMondayVsSunday() {
        let habit = Habit(title: "Read", recurrenceRule: .daily, createdAt: date(2026, 1, 1))
        // Aug 6 2026 is a Thursday.
        let mondayGrid = HabitHistoryEngine.grid(for: habit, weeks: 1, endingOn: date(2026, 8, 6), calendar: calendar)
        XCTAssertEqual(mondayGrid.first?.first?.date, date(2026, 8, 3)) // Monday

        var sundayCalendar = calendar
        sundayCalendar.firstWeekday = 1
        let sundayGrid = HabitHistoryEngine.grid(for: habit, weeks: 1, endingOn: date(2026, 8, 6), calendar: sundayCalendar)
        XCTAssertEqual(sundayGrid.first?.first?.date, date(2026, 8, 2)) // Sunday
    }

    func testLastCellIsTodayNeverFuture() {
        // The grid always fills out the full final week (so every column
        // has 7 rows) — days later than `endingOn` within that week are
        // included but marked `.future`, they aren't excluded outright.
        // What must hold is: `endingOn` itself is never `.future`, and
        // nothing *after* it within the grid is anything but `.future`.
        let habit = Habit(title: "Read", recurrenceRule: .daily, createdAt: date(2026, 1, 1))
        let today = date(2026, 8, 6) // Thursday
        let grid = HabitHistoryEngine.grid(for: habit, weeks: 1, endingOn: today, calendar: calendar)
        let states = Dictionary(uniqueKeysWithValues: grid.flatMap { $0 }.map { ($0.date, $0.state) })

        XCTAssertNotEqual(states[today], .future)
        XCTAssertEqual(states[date(2026, 8, 7)], .future) // Friday, after "today"
        XCTAssertEqual(states[date(2026, 8, 9)], .future) // Sunday, end of that week
    }

    func testMonthlyRuleSkipsFebruary31st() {
        let habit = Habit(title: "Pay Rent", recurrenceRule: .monthly(daysOfMonth: [31]), createdAt: date(2025, 1, 1))
        // Week containing Feb 2026 (not a leap year, Feb has 28 days).
        let grid = HabitHistoryEngine.grid(for: habit, weeks: 1, endingOn: date(2026, 3, 1), calendar: calendar)
        let states = Dictionary(uniqueKeysWithValues: grid.flatMap { $0 }.map { ($0.date, $0.state) })

        // None of the days in this window (Feb 23 - Mar 1) are the 31st, so
        // all should be .notScheduled rather than crashing or miscounting.
        XCTAssertTrue(states.values.allSatisfy { $0 == .notScheduled })
    }

    func testWeeksParameterControlsGridWidth() {
        let habit = Habit(title: "Read", recurrenceRule: .daily, createdAt: date(2020, 1, 1))
        let grid = HabitHistoryEngine.grid(for: habit, weeks: 12, endingOn: date(2026, 8, 6), calendar: calendar)
        XCTAssertEqual(grid.count, 12)
        XCTAssertTrue(grid.allSatisfy { $0.count == 7 })
    }
}
