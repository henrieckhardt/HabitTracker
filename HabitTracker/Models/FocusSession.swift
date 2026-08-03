import Foundation
import SwiftData

@Model
final class FocusSession {
    var id: UUID = UUID()
    var title: String = ""
    var startTime: Date = FocusSession.defaultStartTime()
    var endTime: Date = FocusSession.defaultEndTime()
    var createdAt: Date = Date.now
    var isArchived: Bool = false

    /// `RecurrenceRule` is stored as encoded JSON, not directly — see the
    /// same workaround (and the reason for it) on `Habit.recurrenceRuleData`.
    private var recurrenceRuleData: Data = FocusSession.encode(.daily)

    var recurrenceRule: RecurrenceRule {
        get { FocusSession.decode(recurrenceRuleData) }
        set { recurrenceRuleData = FocusSession.encode(newValue) }
    }

    init(
        title: String,
        startTime: Date,
        endTime: Date,
        recurrenceRule: RecurrenceRule = .daily,
        createdAt: Date = .now,
        isArchived: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.recurrenceRuleData = FocusSession.encode(recurrenceRule)
        self.createdAt = createdAt
        self.isArchived = isArchived
    }

    private static func encode(_ rule: RecurrenceRule) -> Data {
        (try? JSONEncoder().encode(rule)) ?? Data()
    }

    private static func decode(_ data: Data) -> RecurrenceRule {
        (try? JSONDecoder().decode(RecurrenceRule.self, from: data)) ?? .daily
    }

    private static func defaultStartTime() -> Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
    }

    private static func defaultEndTime() -> Date {
        Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: .now) ?? .now
    }
}
