import Foundation
import SwiftData

enum RolloverService {
    private static let lastRolloverCheckKey = "lastRolloverCheckDate"

    /// Moves incomplete ToDos with a past `scheduledDate` onto `today`.
    /// Skips the (potentially expensive) fetch if it already ran today.
    static func rolloverIfNeeded(
        context: ModelContext,
        today: Date = .now,
        calendar: Calendar = .current,
        defaults: UserDefaults = .standard
    ) {
        let startOfToday = calendar.startOfDay(for: today)

        if let lastCheck = defaults.object(forKey: lastRolloverCheckKey) as? Date,
           calendar.isDate(lastCheck, inSameDayAs: startOfToday) {
            return
        }

        let descriptor = FetchDescriptor<ToDo>(
            predicate: #Predicate { !$0.isCompleted && $0.scheduledDate < startOfToday }
        )

        if let overdueToDos = try? context.fetch(descriptor) {
            for toDo in overdueToDos {
                toDo.scheduledDate = startOfToday
                if toDo.reminderTime != nil {
                    NotificationService.scheduleReminder(for: toDo, calendar: calendar)
                }
            }
            if !overdueToDos.isEmpty {
                try? context.save()
            }
        }

        defaults.set(startOfToday, forKey: lastRolloverCheckKey)
    }
}
