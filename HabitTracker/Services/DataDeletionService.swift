import Foundation
import SwiftData
import WidgetKit

/// Backs "Delete All Data" in `SettingsView`, behind a double confirmation
/// there. Ordering here is safety-critical, not incidental: skipping the
/// notification/shield steps before deleting the `FocusSession` objects
/// that identify them would leave an active Screen Time shield with
/// nothing left to ever clear it — the exact orphaned-shield failure mode
/// `FocusBlockingScheduler.cleanUpOrphanedMonitoring`'s doc comment already
/// warns about, except self-inflicted and permanent instead of a
/// development-time accident. This is the one path in this plan's A7 phase
/// explicitly flagged as the worst bug it could ship.
enum DataDeletionService {
    static func deleteAllData(context: ModelContext) {
        let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        let toDos = (try? context.fetch(FetchDescriptor<ToDo>())) ?? []
        let sessions = (try? context.fetch(FetchDescriptor<FocusSession>())) ?? []
        let runs = (try? context.fetch(FetchDescriptor<FocusRun>())) ?? []

        // 1. Cancel every notification this app could have scheduled —
        //    nothing should fire against data that's about to not exist.
        for habit in habits {
            NotificationService.cancelReminders(for: habit)
        }
        for toDo in toDos {
            NotificationService.cancelReminder(for: toDo)
        }
        for session in sessions {
            NotificationService.cancelFocusEnd(for: session)
        }

        // 2. Stop DeviceActivity monitoring and clear any live shield for
        //    every session, while the `FocusSession` objects (and their
        //    ids) still exist to identify which `DeviceActivityName`s are
        //    this app's own.
        for session in sessions {
            FocusBlockingScheduler.stop(session)
        }

        // 3. Sweep up anything iOS still has registered that step 2 didn't
        //    account for — `knownSessionIDs: []` because every session is
        //    about to be deleted anyway, so nothing should survive as
        //    "known".
        FocusBlockingScheduler.cleanUpOrphanedMonitoring(knownSessionIDs: [])

        // 4. Only now delete the actual data. `HabitCompletion` cascades
        //    from `Habit`, and a habit's companion `FocusSession` cascades
        //    with it — standalone sessions (already stopped above) are
        //    deleted explicitly.
        for habit in habits {
            context.delete(habit)
        }
        for toDo in toDos {
            context.delete(toDo)
        }
        for session in sessions where session.ownerHabit == nil {
            context.delete(session)
        }
        for run in runs {
            context.delete(run)
        }
        try? context.save()

        // 5. Reset user-configurable settings to their defaults.
        //    Deliberately NOT `hasCompletedOnboarding`/`onboardingVersion` —
        //    clearing data isn't the same as never having used the app, and
        //    forcing onboarding back onto someone who just wiped their
        //    habits would be a strange, unrequested side effect.
        AppSettings.weekStartWeekday = AppSettings.Default.weekStartWeekday
        AppSettings.defaultReminderMinutes = AppSettings.Default.reminderMinutes
        AppSettings.defaultFocusDurationMinutes = AppSettings.Default.focusDurationMinutes
        AppSettings.promptCompleteAfterFocus = AppSettings.Default.promptCompleteAfterFocus
        AppSettings.defaultFocusExitDifficulty = .easy
        AppSettings.quickFocusSessionID = nil

        // 6. Nudge the widget — otherwise it keeps showing habits/to-dos
        //    that no longer exist until some unrelated change happens to
        //    trigger a refresh.
        WidgetCenter.shared.reloadAllTimelines()
    }
}
