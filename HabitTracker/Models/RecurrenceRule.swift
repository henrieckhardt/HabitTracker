import Foundation

/// Underlying recurrence kinds. The editor UI offers 4 presets (täglich,
/// wöchentlich, an Wochentagen, individuell) that map onto these 3 cases —
/// "wöchentlich" is just `.weekdays` constrained to a single day.
enum RecurrenceRule: Codable, Equatable {
    case daily
    case weekdays(Set<Weekday>)
    case monthly(daysOfMonth: Set<Int>)
}

extension RecurrenceRule {
    /// Short, human-readable description for list rows.
    var summaryText: String {
        switch self {
        case .daily:
            return String(localized: "Täglich")
        case .weekdays(let days):
            let ordered = Weekday.orderedForDisplay.filter { days.contains($0) }
            return ordered.map(\.shortLabel).joined(separator: ", ")
        case .monthly(let days):
            let ordered = days.sorted()
            let dayList = ordered.map { "\($0)." }.joined(separator: ", ")
            return String(localized: "Jeden \(dayList) im Monat")
        }
    }
}
