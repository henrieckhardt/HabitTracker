import XCTest
import SwiftData
@testable import HabitTracker

final class FocusLinkingTests: XCTestCase {
    private func makeInMemoryContext() -> ModelContext {
        let container = try! ModelContainer(
            for: Habit.self, HabitCompletion.self, ToDo.self, FocusSession.self, FocusRun.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func makeQuickFocus() -> FocusSession {
        FocusSession(title: "Quick Focus", startTime: .now, endTime: .now, isOnDemand: true, durationMinutes: 30)
    }

    func testStartingLinkedFocusSetsAllFourFields() throws {
        let context = makeInMemoryContext()
        let toDo = ToDo(title: "Steuererklärung", scheduledDate: .now)
        let session = makeQuickFocus()
        context.insert(toDo)
        context.insert(session)
        try context.save()

        FocusSessionController.start(session, linkedToDo: toDo, context: context)

        XCTAssertEqual(session.activeToDoID, toDo.id)
        XCTAssertNil(session.activeHabitID)
        XCTAssertEqual(session.activeLabel, "Steuererklärung")
        XCTAssertNotNil(session.currentRunID)
    }

    func testStoppingClearsAllFourFields() throws {
        let context = makeInMemoryContext()
        let toDo = ToDo(title: "Steuererklärung", scheduledDate: .now)
        let session = makeQuickFocus()
        context.insert(toDo)
        context.insert(session)
        try context.save()

        FocusSessionController.start(session, linkedToDo: toDo, context: context)
        FocusSessionController.stop(session, context: context)

        XCTAssertNil(session.activeToDoID)
        XCTAssertNil(session.activeHabitID)
        XCTAssertNil(session.activeLabel)
        XCTAssertNil(session.currentRunID)
    }

    func testStartingFocusForAHabitNeverTouchesItsCompanionSession() throws {
        // The hazard this guards against: `FocusBlockingScheduler
        // .registerOneOffSchedule` tears down and replaces whatever
        // `DeviceActivitySchedule` is registered for the session it's given
        // — running an on-demand start directly on a habit's own companion
        // session (its recurring daily time window) would permanently break
        // that window. Starting a focus "for" a habit must always run a
        // *separate*, standalone on-demand session (like Quick Focus) with
        // `linkedHabit` pointing at the habit instead — never the companion
        // itself. This test starts a *different* session with `linkedHabit`
        // set and asserts the companion is left completely untouched.
        let context = makeInMemoryContext()
        let habit = Habit(title: "Yoga", recurrenceRule: .daily)
        let companion = FocusSession(title: "Yoga", startTime: .now, endTime: .now, isOnDemand: false)
        companion.ownerHabit = habit
        habit.focusSession = companion
        let quickFocus = makeQuickFocus()
        context.insert(habit)
        context.insert(companion)
        context.insert(quickFocus)
        try context.save()

        FocusSessionController.start(quickFocus, linkedHabit: habit, context: context)

        XCTAssertNil(companion.activeUntil)
        XCTAssertNil(companion.pendingStart)
        XCTAssertNil(companion.currentRunID)
        XCTAssertNil(companion.activeHabitID)
        XCTAssertTrue(habit.focusSession === companion)
        XCTAssertEqual(quickFocus.activeHabitID, habit.id)
    }

    func testDeletedLinkedToDoFallsBackToDenormalizedLabel() throws {
        let context = makeInMemoryContext()
        let toDo = ToDo(title: "Steuererklärung", scheduledDate: .now)
        let session = makeQuickFocus()
        context.insert(toDo)
        context.insert(session)
        try context.save()

        FocusSessionController.start(session, linkedToDo: toDo, context: context)
        context.delete(toDo)
        try context.save()

        // The session's own denormalized label survives the to-do's deletion...
        XCTAssertEqual(session.activeLabel, "Steuererklärung")

        // ...and so does the FocusRun's.
        let sessionID = session.id
        let descriptor = FetchDescriptor<FocusRun>(predicate: #Predicate { $0.sessionID == sessionID })
        let run = try XCTUnwrap(try context.fetch(descriptor).first)
        XCTAssertEqual(run.linkedTitle, "Steuererklärung")
    }
}
