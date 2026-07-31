import XCTest
import SwiftData
@testable import HabitTracker

final class StreakEngineTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func makeContext() -> ModelContext {
        let container = try! ModelContainer(
            for: Habit.self, HabitCompletion.self, ToDo.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func makeDailyHabit(createdAt: Date, in context: ModelContext) -> Habit {
        let habit = Habit(title: "Test", recurrenceRule: .daily, createdAt: createdAt)
        context.insert(habit)
        return habit
    }

    private func complete(_ habit: Habit, on day: Date, in context: ModelContext) {
        let completion = HabitCompletion(date: day, habit: habit)
        context.insert(completion)
    }

    func testCurrentStreakCountsConsecutiveCompletedDays() {
        let context = makeContext()
        let today = date(2026, 7, 31)
        let habit = makeDailyHabit(createdAt: date(2026, 7, 20), in: context)

        complete(habit, on: date(2026, 7, 29), in: context)
        complete(habit, on: date(2026, 7, 30), in: context)
        complete(habit, on: date(2026, 7, 31), in: context)

        XCTAssertEqual(StreakEngine.currentStreak(for: habit, today: today, calendar: calendar), 3)
    }

    func testCurrentStreakNotBrokenByIncompleteToday() {
        let context = makeContext()
        let today = date(2026, 7, 31)
        let habit = makeDailyHabit(createdAt: date(2026, 7, 20), in: context)

        complete(habit, on: date(2026, 7, 29), in: context)
        complete(habit, on: date(2026, 7, 30), in: context)
        // 31st (today) intentionally left incomplete.

        XCTAssertEqual(StreakEngine.currentStreak(for: habit, today: today, calendar: calendar), 2)
    }

    func testCurrentStreakBreaksOnMissedScheduledDay() {
        let context = makeContext()
        let today = date(2026, 7, 31)
        let habit = makeDailyHabit(createdAt: date(2026, 7, 20), in: context)

        complete(habit, on: date(2026, 7, 30), in: context)
        complete(habit, on: date(2026, 7, 31), in: context)
        // 29th missed -> streak should stop counting before it.

        XCTAssertEqual(StreakEngine.currentStreak(for: habit, today: today, calendar: calendar), 2)
    }

    func testLongestStreakFindsBreakInTheMiddle() {
        let context = makeContext()
        let today = date(2026, 7, 31)
        let habit = makeDailyHabit(createdAt: date(2026, 7, 20), in: context)

        // Early run of 4 days, then a gap, then a shorter run of 2 days.
        complete(habit, on: date(2026, 7, 20), in: context)
        complete(habit, on: date(2026, 7, 21), in: context)
        complete(habit, on: date(2026, 7, 22), in: context)
        complete(habit, on: date(2026, 7, 23), in: context)
        // 24th-29th missed.
        complete(habit, on: date(2026, 7, 30), in: context)
        complete(habit, on: date(2026, 7, 31), in: context)

        XCTAssertEqual(StreakEngine.longestStreak(for: habit, today: today, calendar: calendar), 4)
    }

    func testCompletionRateOverLastDays() {
        let context = makeContext()
        let today = date(2026, 7, 31)
        let habit = makeDailyHabit(createdAt: date(2026, 7, 27), in: context)

        // 4 scheduled days in range (27,28,29,30,31 = 5 days), 2 completed.
        complete(habit, on: date(2026, 7, 30), in: context)
        complete(habit, on: date(2026, 7, 31), in: context)

        let rate = StreakEngine.completionRate(for: habit, lastDays: 30, today: today, calendar: calendar)
        XCTAssertEqual(rate, 2.0 / 5.0, accuracy: 0.0001)
    }
}
