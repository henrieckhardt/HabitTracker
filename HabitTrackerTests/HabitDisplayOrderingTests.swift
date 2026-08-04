import XCTest
import SwiftData
@testable import HabitTracker

final class HabitDisplayOrderingTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func timeOnly(_ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: hour, minute: minute))!
    }

    private func makeContext() -> ModelContext {
        let container = try! ModelContainer(
            for: Habit.self, HabitCompletion.self, ToDo.self, FocusSession.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func makeHabit(title: String, in context: ModelContext) -> Habit {
        let habit = Habit(title: title)
        context.insert(habit)
        return habit
    }

    private func attachWindow(to habit: Habit, start: (Int, Int), in context: ModelContext) {
        let session = FocusSession(title: habit.title, startTime: timeOnly(start.0, start.1), endTime: timeOnly(start.0 + 1, start.1))
        context.insert(session)
        habit.focusSession = session
    }

    func testUntimedHabitsKeepCreationOrder() {
        let context = makeContext()
        let first = makeHabit(title: "First", in: context)
        let second = makeHabit(title: "Second", in: context)

        let result = HabitDisplayOrdering.sortedForDay([second, first], calendar: calendar)
        XCTAssertEqual(result.map(\.title), ["Second", "First"])
    }

    func testTimedHabitSortsAfterUntimedHabits() {
        let context = makeContext()
        let untimed = makeHabit(title: "Untimed", in: context)
        let timed = makeHabit(title: "Timed", in: context)
        attachWindow(to: timed, start: (7, 0), in: context)

        let result = HabitDisplayOrdering.sortedForDay([timed, untimed], calendar: calendar)
        XCTAssertEqual(result.map(\.title), ["Untimed", "Timed"])
    }

    func testTimedHabitsSortAscendingByStartTime() {
        let context = makeContext()
        let evening = makeHabit(title: "Evening", in: context)
        attachWindow(to: evening, start: (20, 0), in: context)
        let morning = makeHabit(title: "Morning", in: context)
        attachWindow(to: morning, start: (7, 0), in: context)
        let noon = makeHabit(title: "Noon", in: context)
        attachWindow(to: noon, start: (12, 0), in: context)

        let result = HabitDisplayOrdering.sortedForDay([evening, morning, noon], calendar: calendar)
        XCTAssertEqual(result.map(\.title), ["Morning", "Noon", "Evening"])
    }

    func testTimedHabitsWithSameStartTimeKeepStableOrder() {
        let context = makeContext()
        let firstHabit = makeHabit(title: "A", in: context)
        attachWindow(to: firstHabit, start: (9, 0), in: context)
        let secondHabit = makeHabit(title: "B", in: context)
        attachWindow(to: secondHabit, start: (9, 0), in: context)

        let result = HabitDisplayOrdering.sortedForDay([firstHabit, secondHabit], calendar: calendar)
        XCTAssertEqual(result.map(\.title), ["A", "B"])
    }
}
