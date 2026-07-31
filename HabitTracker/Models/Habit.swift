import Foundation
import SwiftData

@Model
final class Habit {
    var id: UUID = UUID()
    var title: String = ""
    var icon: String = "checkmark.circle"
    var colorTag: String = "blue"
    var createdAt: Date = Date.now
    var isArchived: Bool = false
    var reminderTime: Date?

    /// `RecurrenceRule` (an enum with `Set`-valued associated data) crashes
    /// SwiftData's schema macro if stored directly, so it's persisted as
    /// encoded JSON and exposed through the computed `recurrenceRule` below.
    private var recurrenceRuleData: Data = Habit.encode(.daily)

    var recurrenceRule: RecurrenceRule {
        get { Habit.decode(recurrenceRuleData) }
        set { recurrenceRuleData = Habit.encode(newValue) }
    }

    @Relationship(deleteRule: .cascade, inverse: \HabitCompletion.habit)
    var completions: [HabitCompletion] = []

    init(
        title: String,
        icon: String = "checkmark.circle",
        colorTag: String = "blue",
        recurrenceRule: RecurrenceRule = .daily,
        createdAt: Date = .now,
        isArchived: Bool = false,
        reminderTime: Date? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.icon = icon
        self.colorTag = colorTag
        self.recurrenceRuleData = Habit.encode(recurrenceRule)
        self.createdAt = createdAt
        self.isArchived = isArchived
        self.reminderTime = reminderTime
    }

    func isCompleted(on date: Date, calendar: Calendar = .current) -> Bool {
        completions.contains { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func completion(on date: Date, calendar: Calendar = .current) -> HabitCompletion? {
        completions.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private static func encode(_ rule: RecurrenceRule) -> Data {
        (try? JSONEncoder().encode(rule)) ?? Data()
    }

    private static func decode(_ data: Data) -> RecurrenceRule {
        (try? JSONDecoder().decode(RecurrenceRule.self, from: data)) ?? .daily
    }
}
