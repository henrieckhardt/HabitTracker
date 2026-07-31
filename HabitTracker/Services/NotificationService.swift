import Foundation
import UserNotifications

enum NotificationService {
    static let completeActionIdentifier = "COMPLETE_HABIT"
    static let categoryIdentifier = "HABIT_REMINDER"
    static let habitIDKey = "habitID"

    /// Registers the "Erledigt" quick-action category. Call once at app launch.
    static func registerCategories() {
        let completeAction = UNNotificationAction(
            identifier: completeActionIdentifier,
            title: "Erledigt",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [completeAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    @discardableResult
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Cancels any existing reminders for the habit, then schedules new ones
    /// matching its current recurrence rule and reminder time.
    static func scheduleReminders(for habit: Habit, calendar: Calendar = .current) {
        cancelReminders(for: habit)
        guard let time = habit.reminderTime else { return }

        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        let content = UNMutableNotificationContent()
        content.title = habit.title
        content.body = "Zeit für deinen Habit"
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier
        content.userInfo = [habitIDKey: habit.id.uuidString]

        func addRequest(suffix: String, dateComponents: DateComponents) {
            var comps = dateComponents
            comps.hour = timeComponents.hour
            comps.minute = timeComponents.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(
                identifier: identifierPrefix(for: habit) + suffix,
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }

        switch habit.recurrenceRule {
        case .daily:
            addRequest(suffix: "daily", dateComponents: DateComponents())
        case .weekdays(let days):
            for day in days {
                addRequest(suffix: "weekday-\(day.rawValue)", dateComponents: DateComponents(weekday: day.rawValue))
            }
        case .monthly(let daysOfMonth):
            for day in daysOfMonth {
                addRequest(suffix: "day-\(day)", dateComponents: DateComponents(day: day))
            }
        }
    }

    static func cancelReminders(for habit: Habit) {
        let prefix = identifierPrefix(for: habit)
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let idsToRemove = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: idsToRemove)
        }
    }

    private static func identifierPrefix(for habit: Habit) -> String {
        "habit-reminder-\(habit.id.uuidString)-"
    }
}
