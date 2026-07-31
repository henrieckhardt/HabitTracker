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

    var shortLabel: String {
        switch self {
        case .sunday: "So"
        case .monday: "Mo"
        case .tuesday: "Di"
        case .wednesday: "Mi"
        case .thursday: "Do"
        case .friday: "Fr"
        case .saturday: "Sa"
        }
    }

    /// Monday-first ordering for UI display.
    static var orderedForDisplay: [Weekday] {
        [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
    }
}
