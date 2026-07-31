import XCTest
import SwiftData
@testable import HabitTracker

final class RolloverServiceTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func makeInMemoryContext() -> ModelContext {
        let container = try! ModelContainer(
            for: Habit.self, HabitCompletion.self, ToDo.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "RolloverServiceTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    func testOverdueIncompleteToDoIsMovedToToday() throws {
        let context = makeInMemoryContext()
        let defaults = makeDefaults()
        let today = date(2026, 7, 31)
        let yesterday = date(2026, 7, 30)

        let overdue = ToDo(title: "Steuererklärung", scheduledDate: yesterday)
        context.insert(overdue)
        try context.save()

        RolloverService.rolloverIfNeeded(context: context, today: today, calendar: calendar, defaults: defaults)

        XCTAssertTrue(calendar.isDate(overdue.scheduledDate, inSameDayAs: today))
    }

    func testCompletedOverdueToDoIsNotMoved() throws {
        let context = makeInMemoryContext()
        let defaults = makeDefaults()
        let today = date(2026, 7, 31)
        let yesterday = date(2026, 7, 30)

        let completed = ToDo(title: "Erledigt", scheduledDate: yesterday, isCompleted: true)
        context.insert(completed)
        try context.save()

        RolloverService.rolloverIfNeeded(context: context, today: today, calendar: calendar, defaults: defaults)

        XCTAssertTrue(calendar.isDate(completed.scheduledDate, inSameDayAs: yesterday))
    }

    func testRolloverOnlyRunsOncePerDay() throws {
        let context = makeInMemoryContext()
        let defaults = makeDefaults()
        let today = date(2026, 7, 31)
        let yesterday = date(2026, 7, 30)

        let overdue = ToDo(title: "Steuererklärung", scheduledDate: yesterday)
        context.insert(overdue)
        try context.save()

        // First call marks the day as checked without necessarily having run rollover yet
        // (simulating the check happening before the ToDo existed is out of scope here);
        // what matters is a second call on the same day is a no-op even if we mutate state back.
        RolloverService.rolloverIfNeeded(context: context, today: today, calendar: calendar, defaults: defaults)
        overdue.scheduledDate = yesterday // simulate manual edit back to an overdue date

        RolloverService.rolloverIfNeeded(context: context, today: today, calendar: calendar, defaults: defaults)

        XCTAssertTrue(calendar.isDate(overdue.scheduledDate, inSameDayAs: yesterday))
    }
}
