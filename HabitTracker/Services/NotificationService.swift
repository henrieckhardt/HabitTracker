import Foundation
import UserNotifications

enum NotificationService {
    static let completeHabitActionIdentifier = "COMPLETE_HABIT"
    static let habitCategoryIdentifier = "HABIT_REMINDER"
    static let habitIDKey = "habitID"

    static let completeToDoActionIdentifier = "COMPLETE_TODO"
    static let toDoCategoryIdentifier = "TODO_REMINDER"
    static let toDoIDKey = "toDoID"

    /// Registers the "Erledigt" quick-action categories. Call once at app launch.
    static func registerCategories() {
        let completeHabitAction = UNNotificationAction(
            identifier: completeHabitActionIdentifier,
            title: String(localized: "Erledigt"),
            options: []
        )
        let habitCategory = UNNotificationCategory(
            identifier: habitCategoryIdentifier,
            actions: [completeHabitAction],
            intentIdentifiers: [],
            options: []
        )

        let completeToDoAction = UNNotificationAction(
            identifier: completeToDoActionIdentifier,
            title: String(localized: "Erledigt"),
            options: []
        )
        let toDoCategory = UNNotificationCategory(
            identifier: toDoCategoryIdentifier,
            actions: [completeToDoAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([habitCategory, toDoCategory])
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
        content.body = String(localized: "Zeit für deinen Habit")
        content.sound = .default
        content.categoryIdentifier = habitCategoryIdentifier
        content.userInfo = [habitIDKey: habit.id.uuidString]

        func addRequest(suffix: String, dateComponents: DateComponents) {
            var comps = dateComponents
            comps.hour = timeComponents.hour
            comps.minute = timeComponents.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(
                identifier: habitIdentifierPrefix(for: habit) + suffix,
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
        cancelRequests(withPrefix: habitIdentifierPrefix(for: habit))
    }

    /// Cancels any existing reminder for the ToDo, then schedules a one-time
    /// reminder on its scheduled date at the given time (if set). Call again
    /// whenever `scheduledDate` changes (e.g. on rollover) to move the trigger.
    static func scheduleReminder(for toDo: ToDo, calendar: Calendar = .current) {
        cancelReminder(for: toDo)
        guard let time = toDo.reminderTime else { return }

        var comps = calendar.dateComponents([.year, .month, .day], from: toDo.scheduledDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        comps.hour = timeComponents.hour
        comps.minute = timeComponents.minute

        let content = UNMutableNotificationContent()
        content.title = toDo.title
        content.body = String(localized: "Fällig heute")
        content.sound = .default
        content.categoryIdentifier = toDoCategoryIdentifier
        content.userInfo = [toDoIDKey: toDo.id.uuidString]

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: toDoIdentifier(for: toDo),
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelReminder(for toDo: ToDo) {
        cancelRequests(withPrefix: toDoIdentifier(for: toDo))
    }

    private static func cancelRequests(withPrefix prefix: String) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let idsToRemove = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: idsToRemove)
        }
    }

    private static func habitIdentifierPrefix(for habit: Habit) -> String {
        "habit-reminder-\(habit.id.uuidString)-"
    }

    private static func toDoIdentifier(for toDo: ToDo) -> String {
        "todo-reminder-\(toDo.id.uuidString)"
    }
}
