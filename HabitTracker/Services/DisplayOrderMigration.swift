import Foundation
import SwiftData

/// One-time backfill for `Habit.sortOrder`/`ToDo.sortOrder`: rows that
/// existed before those fields were introduced got the type's static
/// default (`0`) applied by SwiftData's lightweight migration, which would
/// otherwise leave every pre-existing row tied for the same position.
/// Assigning each one its own `createdAt`-based value here reproduces the
/// creation-date order the app already showed before drag-to-reorder
/// existed. Safe to call on every launch — already-migrated rows (whose
/// `sortOrder` is never exactly `0`, see the fields' doc comments) are
/// left untouched.
enum DisplayOrderMigration {
    static func run(context: ModelContext) {
        let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        for habit in habits where habit.sortOrder == 0 {
            habit.sortOrder = habit.createdAt.timeIntervalSinceReferenceDate
        }

        let toDos = (try? context.fetch(FetchDescriptor<ToDo>())) ?? []
        for toDo in toDos where toDo.sortOrder == 0 {
            toDo.sortOrder = toDo.createdAt.timeIntervalSinceReferenceDate
        }

        try? context.save()
    }
}
