import Foundation
import SwiftData
import UserNotifications

/// Handles the "Erledigt" quick-action from habit reminder notifications,
/// marking the habit complete for today directly against the persistent
/// store — without requiring the app to be foregrounded.
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
        guard response.actionIdentifier == NotificationService.completeActionIdentifier,
              let habitIDString = response.notification.request.content.userInfo[NotificationService.habitIDKey] as? String,
              let habitID = UUID(uuidString: habitIDString) else { return }

        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<Habit>(predicate: #Predicate { $0.id == habitID })
        guard let habit = try? context.fetch(descriptor).first else { return }

        let today = Calendar.current.startOfDay(for: .now)
        if habit.completion(on: today) == nil {
            let completion = HabitCompletion(date: today, habit: habit)
            context.insert(completion)
            try? context.save()
        }
    }
}
