import XCTest
import SwiftData
@testable import HabitTracker

final class DataDeletionServiceTests: XCTestCase {
    private func makeContext() -> ModelContext {
        let container = try! ModelContainer(
            for: Habit.self, HabitCompletion.self, ToDo.self, FocusSession.self, FocusRun.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    func testDeleteAllDataRemovesEveryEntity() throws {
        let context = makeContext()
        let habit = Habit(title: "Read", recurrenceRule: .daily)
        context.insert(habit)
        context.insert(HabitCompletion(date: .now, habit: habit))
        context.insert(ToDo(title: "Buy milk", scheduledDate: .now))
        let session = FocusSession(title: "Deep Work", startTime: .now, endTime: .now, isOnDemand: true, durationMinutes: 30)
        context.insert(session)
        context.insert(FocusRun(sessionID: session.id, sessionTitle: session.title, startedAt: .now, plannedEnd: .now))
        try context.save()

        DataDeletionService.deleteAllData(context: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<Habit>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<HabitCompletion>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ToDo>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<FocusSession>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<FocusRun>()).count, 0)
    }

    func testDeleteAllDataAlsoRemovesAHabitsCompanionSession() throws {
        let context = makeContext()
        let habit = Habit(title: "Yoga", recurrenceRule: .daily)
        let companion = FocusSession(title: "Yoga", startTime: .now, endTime: .now)
        companion.ownerHabit = habit
        habit.focusSession = companion
        context.insert(habit)
        context.insert(companion)
        try context.save()

        DataDeletionService.deleteAllData(context: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<Habit>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<FocusSession>()).count, 0)
    }

    func testDeleteAllDataResetsSettingsToDefaults() throws {
        let context = makeContext()
        AppSettings.weekStartWeekday = 1
        AppSettings.defaultReminderMinutes = 8 * 60
        AppSettings.defaultFocusDurationMinutes = 45
        AppSettings.promptCompleteAfterFocus = false
        AppSettings.quickFocusSessionID = UUID()

        DataDeletionService.deleteAllData(context: context)

        XCTAssertEqual(AppSettings.weekStartWeekday, AppSettings.Default.weekStartWeekday)
        XCTAssertEqual(AppSettings.defaultReminderMinutes, AppSettings.Default.reminderMinutes)
        XCTAssertEqual(AppSettings.defaultFocusDurationMinutes, AppSettings.Default.focusDurationMinutes)
        XCTAssertEqual(AppSettings.promptCompleteAfterFocus, AppSettings.Default.promptCompleteAfterFocus)
        XCTAssertNil(AppSettings.quickFocusSessionID)
    }

    func testDeleteAllDataDoesNotResetOnboardingState() throws {
        let context = makeContext()
        AppSettings.hasCompletedOnboarding = true
        AppSettings.onboardingVersion = AppSettings.currentOnboardingVersion

        DataDeletionService.deleteAllData(context: context)

        XCTAssertTrue(AppSettings.hasCompletedOnboarding)
        XCTAssertEqual(AppSettings.onboardingVersion, AppSettings.currentOnboardingVersion)
    }

    func testDeleteAllDataOnAnEmptyStoreDoesNotThrowOrCrash() {
        let context = makeContext()
        DataDeletionService.deleteAllData(context: context)
        XCTAssertEqual((try? context.fetch(FetchDescriptor<Habit>()))?.count, 0)
    }
}
