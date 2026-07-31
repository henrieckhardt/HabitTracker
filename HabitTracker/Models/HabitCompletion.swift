import Foundation
import SwiftData

@Model
final class HabitCompletion {
    var id: UUID = UUID()
    var date: Date = Date.now
    var completedAt: Date?
    var habit: Habit?

    init(date: Date, completedAt: Date = .now, habit: Habit? = nil) {
        self.id = UUID()
        self.date = date
        self.completedAt = completedAt
        self.habit = habit
    }
}
