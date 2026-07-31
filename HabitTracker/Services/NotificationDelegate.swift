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

        switch response.actionIdentifier {
        case NotificationService.completeHabitActionIdentifier:
            completeHabit(userInfo: userInfo, context: context)
        case NotificationService.completeToDoActionIdentifier:
            completeToDo(userInfo: userInfo, context: context)
        default:
            break
        }
    }

    private func completeHabit(userInfo: [AnyHashable: Any], context: ModelContext) {
        guard let habitIDString = userInfo[NotificationService.habitIDKey] as? String,
              let habitID = UUID(uuidString: habitIDString) else { return }

        let descriptor = FetchDescriptor<Habit>(predicate: #Predicate { $0.id == habitID })
        guard let habit = try? context.fetch(descriptor).first else { return }

        let today = Calendar.current.startOfDay(for: .now)
        if habit.completion(on: today) == nil {
            let completion = HabitCompletion(date: today, habit: habit)
            context.insert(completion)
            try? context.save()
        }
    }

    private func completeToDo(userInfo: [AnyHashable: Any], context: ModelContext) {
        guard let toDoIDString = userInfo[NotificationService.toDoIDKey] as? String,
              let toDoID = UUID(uuidString: toDoIDString) else { return }

        let descriptor = FetchDescriptor<ToDo>(predicate: #Predicate { $0.id == toDoID })
        guard let toDo = try? context.fetch(descriptor).first else { return }

        toDo.isCompleted = true
        toDo.completedAt = .now
        try? context.save()
    }
}
