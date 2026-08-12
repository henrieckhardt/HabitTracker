import Foundation
import SwiftData

/// The one place a habit or to-do actually gets marked complete/incomplete.
/// Before this existed, the same handful of lines (find the object, flip
/// its completion state, cancel/reschedule the reminder) were duplicated
/// across `DayItemRow.toggle()`, `NotificationDelegate`'s notification
/// actions, and — with the widget's `AppIntent`s — would have become a
/// third copy. Both functions take an `id` and fetch rather than an
/// already-loaded model object, since the widget/notification call sites
/// only ever have a `UUID` (crossing from a different process, or from
/// notification `userInfo`), never a live SwiftData reference.
enum ItemCompletionService {
    /// Toggles whether `id` is completed on `date`. Unknown `id` is a
    /// silent no-op — the widget/a notification can be acting on an item
    /// that's since been deleted.
    static func toggleHabit(id: UUID, on date: Date, context: ModelContext, calendar: Calendar = .current) {
        let descriptor = FetchDescriptor<Habit>(predicate: #Predicate { $0.id == id })
        guard let habit = try? context.fetch(descriptor).first else { return }

        let dayStart = calendar.startOfDay(for: date)
        if let completion = habit.completion(on: dayStart, calendar: calendar) {
            context.delete(completion)
        } else {
            context.insert(HabitCompletion(date: dayStart, habit: habit))
        }
        try? context.save()
    }

    /// Toggles `id`'s completion, updating its reminder to match — cancels
    /// a pending one when completing, reschedules it when un-completing
    /// (matching `DayItemRow.toggle()`'s original behavior; a reminder for
    /// an already-completed to-do would fire pointlessly).
    static func toggleToDo(id: UUID, context: ModelContext) {
        let descriptor = FetchDescriptor<ToDo>(predicate: #Predicate { $0.id == id })
        guard let toDo = try? context.fetch(descriptor).first else { return }

        toDo.isCompleted.toggle()
        toDo.completedAt = toDo.isCompleted ? .now : nil
        if toDo.isCompleted {
            NotificationService.cancelReminder(for: toDo)
        } else if toDo.reminderTime != nil {
            NotificationService.scheduleReminder(for: toDo)
        }
        try? context.save()
    }
}
