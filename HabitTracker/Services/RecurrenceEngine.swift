import Foundation

enum RecurrenceEngine {
    /// Whether a habit with the given rule is due on `date`.
    ///
    /// For `.monthly`, days that don't exist in a given month (e.g. the 31st
    /// in February) simply never match any date in that month — no explicit
    /// skip logic is needed.
    static func isScheduled(_ rule: RecurrenceRule, on date: Date, calendar: Calendar = .current) -> Bool {
        switch rule {
        case .daily:
            return true
        case .weekdays(let days):
            let weekday = Weekday(calendarWeekday: calendar.component(.weekday, from: date))
            return days.contains(weekday)
        case .monthly(let daysOfMonth):
            let day = calendar.component(.day, from: date)
            return daysOfMonth.contains(day)
        }
    }
}
