import XCTest
@testable import HabitTracker

final class AggregateStatsEngineTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.firstWeekday = 2 // Monday
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func completedHabit(title: String, rule: RecurrenceRule, on date: Date, createdAt: Date) -> Habit {
        let habit = Habit(title: title, recurrenceRule: rule, createdAt: createdAt)
        habit.completions.append(HabitCompletion(date: date, habit: habit))
        return habit
    }

    func testTodayProgressWithMixedScheduledHabits() {
        let today = date(2026, 8, 6) // Thursday
        // Daily habit, completed today.
        let daily = completedHabit(title: "Read", rule: .daily, on: today, createdAt: date(2026, 1, 1))
        // Weekdays habit scheduled today (Thu) but NOT completed.
        let weekdays = Habit(title: "Gym", recurrenceRule: .weekdays([.tuesday, .thursday]), createdAt: date(2026, 1, 1))
        // Weekly habit not scheduled today at all — must not affect the rate.
        let weekly = Habit(title: "Laundry", recurrenceRule: .weekdays([.saturday]), createdAt: date(2026, 1, 1))

        let rate = AggregateStatsEngine.todayProgress(habits: [daily, weekdays, weekly], on: today, calendar: calendar)

        XCTAssertEqual(rate, 0.5, accuracy: 0.0001) // 1 of 2 scheduled-today habits completed
    }

    func testTodayProgressWithNoScheduledHabitsIsZeroNotCrash() {
        let today = date(2026, 8, 6)
        let habit = Habit(title: "Laundry", recurrenceRule: .weekdays([.saturday]), createdAt: date(2026, 1, 1))

        let rate = AggregateStatsEngine.todayProgress(habits: [habit], on: today, calendar: calendar)

        XCTAssertEqual(rate, 0)
    }

    func testWeekCompletionRateSpansAMonthBoundary() {
        // Week of Jul 27 - Aug 2, 2026 (Monday-first) straddles July/August.
        let monday = date(2026, 7, 27)
        let wednesday = date(2026, 7, 29)
        let habit = completedHabit(title: "Read", rule: .daily, on: monday, createdAt: date(2026, 1, 1))
        // Only Monday is completed; evaluate as of Wednesday (mid-week) so
        // Thursday-Sunday don't count as missed.
        let rate = AggregateStatsEngine.weekCompletionRate(habits: [habit], containing: wednesday, calendar: calendar)

        // Scheduled days counted: Mon, Tue, Wed = 3; completed: Mon = 1.
        XCTAssertEqual(rate, 1.0 / 3.0, accuracy: 0.0001)
    }

    func testWeekCompletionRateWithEmptyHabitsIsZero() {
        let rate = AggregateStatsEngine.weekCompletionRate(habits: [], containing: date(2026, 8, 6), calendar: calendar)
        XCTAssertEqual(rate, 0)
    }

    func testToDoStatsCountsOnlyTodaysToDos() {
        let today = date(2026, 8, 6)
        let tomorrow = date(2026, 8, 7)
        let doneToday = ToDo(title: "A", scheduledDate: today, isCompleted: true)
        let pendingToday = ToDo(title: "B", scheduledDate: today)
        let futureToDo = ToDo(title: "C", scheduledDate: tomorrow)

        let stats = AggregateStatsEngine.toDoStats(toDos: [doneToday, pendingToday, futureToDo], on: today, calendar: calendar)

        XCTAssertEqual(stats.completed, 1)
        XCTAssertEqual(stats.total, 2)
    }

    func testBestCurrentStreakPicksTheMaximum() {
        let today = date(2026, 8, 6)
        let shortStreakHabit = completedHabit(title: "A", rule: .daily, on: today, createdAt: date(2026, 8, 5))
        let longerStreakHabit = Habit(title: "B", recurrenceRule: .daily, createdAt: date(2026, 8, 1))
        for offset in 0...5 {
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            longerStreakHabit.completions.append(HabitCompletion(date: day, habit: longerStreakHabit))
        }

        let best = AggregateStatsEngine.bestCurrentStreak(habits: [shortStreakHabit, longerStreakHabit], today: today, calendar: calendar)

        XCTAssertEqual(best, 6)
    }

    func testEmptyStoreProducesZeroEverywhere() {
        let today = date(2026, 8, 6)
        XCTAssertEqual(AggregateStatsEngine.todayProgress(habits: [], on: today, calendar: calendar), 0)
        XCTAssertEqual(AggregateStatsEngine.weekCompletionRate(habits: [], containing: today, calendar: calendar), 0)
        let stats = AggregateStatsEngine.toDoStats(toDos: [], on: today, calendar: calendar)
        XCTAssertEqual(stats.completed, 0)
        XCTAssertEqual(stats.total, 0)
        XCTAssertEqual(AggregateStatsEngine.bestCurrentStreak(habits: [], today: today, calendar: calendar), 0)
    }
}
