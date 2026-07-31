import SwiftUI
import SwiftData
import UserNotifications

@main
struct HabitTrackerApp: App {
    private let modelContainer: ModelContainer
    private let notificationDelegate: NotificationDelegate

    init() {
        let container = try! ModelContainer(for: Habit.self, HabitCompletion.self, ToDo.self)
        modelContainer = container

        let delegate = NotificationDelegate(modelContainer: container)
        notificationDelegate = delegate
        UNUserNotificationCenter.current().delegate = delegate
        NotificationService.registerCategories()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(modelContainer)
    }
}
