import Foundation
import SwiftData
import UserNotifications

/// Handles the "Erledigt" quick-action from habit/ToDo reminder notifications,
/// marking the item complete directly against the persistent store —
/// without requiring the app to be foregrounded.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let context = ModelContext(modelContainer)

        // This delegate method runs in the app process even on a
        // notification-triggered background launch, so it's a
        // reconciliation opportunity independent of which notification this
        // particular response was for — including, eventually, a dedicated
        // focus-end notification (not scheduled yet; see the Focus↔task
        // linking work).
        FocusSessionController.reconcile(context: context)

        switch response.actionIdentifier {
        case NotificationService.completeHabitActionIdentifier:
            completeHabit(userInfo: userInfo, context: context)
        case NotificationService.completeToDoActionIdentifier:
            completeToDo(userInfo: userInfo, context: context)
        default:
            break
        }
    }

    /// Routes through `ItemCompletionService` for the actual mutation, but
    /// — unlike `DayItemRow`'s checkbox or the widget's `AppIntent`, which
    /// both want a genuine toggle — guards it behind "not already complete"
    /// first. This is a one-shot "Erledigt" action, not a checkbox: a
    /// notification the user already handled some other way (completed the
    /// habit in-app, then tapped a still-lingering notification banner)
    /// must not silently *uncomplete* it.
    private func completeHabit(userInfo: [AnyHashable: Any], context: ModelContext) {
        guard let habitIDString = userInfo[NotificationService.habitIDKey] as? String,
              let habitID = UUID(uuidString: habitIDString) else { return }

        let descriptor = FetchDescriptor<Habit>(predicate: #Predicate { $0.id == habitID })
        guard let habit = try? context.fetch(descriptor).first, habit.completion(on: .now) == nil else { return }

        ItemCompletionService.toggleHabit(id: habitID, on: .now, context: context)
    }

    private func completeToDo(userInfo: [AnyHashable: Any], context: ModelContext) {
        guard let toDoIDString = userInfo[NotificationService.toDoIDKey] as? String,
              let toDoID = UUID(uuidString: toDoIDString) else { return }

        let descriptor = FetchDescriptor<ToDo>(predicate: #Predicate { $0.id == toDoID })
        guard let toDo = try? context.fetch(descriptor).first, !toDo.isCompleted else { return }

        ItemCompletionService.toggleToDo(id: toDoID, context: context)
    }
}
