import Foundation

/// The single source of truth for "which day starts the week" across the
/// app. `WeekView` used to hardcode `firstWeekday = 2` (Monday) directly;
/// as of the Focus/Habits coherence work, the 12-week habit history grid
/// and the weekly focus/aggregate stats all need that *same* week
/// definition, and it must be user-configurable (see
/// `AppSettings.weekStartWeekday`). Centralizing it here means every one of
/// those call sites stays in sync automatically.
enum CalendarProvider {
    /// Pure and testable: builds a `Calendar` with the given first weekday,
    /// independent of `AppSettings`.
    static func calendar(firstWeekday: Int) -> Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    /// The calendar the app should use everywhere "this week" matters,
    /// reflecting the user's current setting.
    static var current: Calendar {
        calendar(firstWeekday: AppSettings.weekStartWeekday)
    }
}
