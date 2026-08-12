import XCTest
import SwiftData
@testable import HabitTracker

final class ItemCompletionServiceTests: XCTestCase {
    private func makeContext() -> ModelContext {
        let container = try! ModelContainer(
            for: Habit.self, HabitCompletion.self, ToDo.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    func testTogglingAHabitTwiceLeavesNoCompletion() throws {
        let context = makeContext()
        let habit = Habit(title: "Read", recurrenceRule: .daily)
        context.insert(habit)
        try context.save()

        ItemCompletionService.toggleHabit(id: habit.id, on: .now, context: context)
        XCTAssertNotNil(habit.completion(on: .now))

        ItemCompletionService.toggleHabit(id: habit.id, on: .now, context: context)
        XCTAssertNil(habit.completion(on: .now))

        let descriptor = FetchDescriptor<HabitCompletion>()
        XCTAssertEqual(try context.fetch(descriptor).count, 0)
    }

    func testTogglingAToDoSetsAndClearsCompletedAt() throws {
        let context = makeContext()
        let toDo = ToDo(title: "Buy milk", scheduledDate: .now)
        context.insert(toDo)
        try context.save()

        ItemCompletionService.toggleToDo(id: toDo.id, context: context)
        XCTAssertTrue(toDo.isCompleted)
        XCTAssertNotNil(toDo.completedAt)

        ItemCompletionService.toggleToDo(id: toDo.id, context: context)
        XCTAssertFalse(toDo.isCompleted)
        XCTAssertNil(toDo.completedAt)
    }

    func testUnknownHabitIDIsANoOp() throws {
        let context = makeContext()
        // Should not throw, crash, or insert anything.
        ItemCompletionService.toggleHabit(id: UUID(), on: .now, context: context)

        let descriptor = FetchDescriptor<HabitCompletion>()
        XCTAssertEqual(try context.fetch(descriptor).count, 0)
    }

    func testUnknownToDoIDIsANoOp() throws {
        let context = makeContext()
        ItemCompletionService.toggleToDo(id: UUID(), context: context)
        // No crash is the assertion here; nothing else to observe.
    }
}
