import Foundation

enum Weekday: Int, Codable, CaseIterable, Identifiable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    /// Matches `Calendar.component(.weekday, from:)`, which is 1 = Sunday ... 7 = Saturday.
    init(calendarWeekday: Int) {
        self = Weekday(rawValue: calendarWeekday) ?? .sunday
    }

    /// Locale-adaptive short weekday abbreviation (e.g. "Mo" in German,
    /// "Mon" in English) — derived from `Calendar` instead of a hardcoded
    /// German switch, so it stays correct as more languages are added
    /// without touching this file again.
    var shortLabel: String {
        Calendar.autoupdatingCurrent.shortStandaloneWeekdaySymbols[rawValue - 1]
    }

    /// Monday-first ordering for UI display.
    static var orderedForDisplay: [Weekday] {
        [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
    }
}
