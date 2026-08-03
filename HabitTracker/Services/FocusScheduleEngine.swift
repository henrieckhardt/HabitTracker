import Foundation

enum FocusScheduleEngine {
    /// Whether `session` is currently active: today matches its recurrence
    /// rule and `date`'s time-of-day falls within its start/end window
    /// (start inclusive, end exclusive).
    static func isActive(_ session: FocusSession, at date: Date = .now, calendar: Calendar = .current) -> Bool {
        guard RecurrenceEngine.isScheduled(session.recurrenceRule, on: date, calendar: calendar) else {
            return false
        }
        let currentMinutes = minutesSinceMidnight(of: date, calendar: calendar)
        let startMinutes = minutesSinceMidnight(of: session.startTime, calendar: calendar)
        let endMinutes = minutesSinceMidnight(of: session.endTime, calendar: calendar)
        return currentMinutes >= startMinutes && currentMinutes < endMinutes
    }

    /// First session (if any) that's currently active, for a UI banner like
    /// "Gerade aktiv: <title> bis HH:MM".
    static func currentlyActiveSession(in sessions: [FocusSession], at date: Date = .now, calendar: Calendar = .current) -> FocusSession? {
        sessions.first { isActive($0, at: date, calendar: calendar) }
    }

    private static func minutesSinceMidnight(of date: Date, calendar: Calendar) -> Int {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }
}
