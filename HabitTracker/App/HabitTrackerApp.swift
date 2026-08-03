import SwiftUI
import SwiftData
import UserNotifications

@main
struct HabitTrackerApp: App {
    private let modelContainer: ModelContainer
    private let notificationDelegate: NotificationDelegate

    init() {
        // Stored in the shared App Group container (not the app's private
        // container) so the FocusShieldMonitor/FocusShieldConfiguration
        // extensions can read FocusSession data directly.
        let container = try! ModelContainer(
            for: Habit.self, HabitCompletion.self, ToDo.self, FocusSession.self,
            configurations: AppGroup.makeModelConfiguration()
        )
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
