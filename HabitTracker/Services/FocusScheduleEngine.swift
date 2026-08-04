import Foundation

enum FocusScheduleEngine {
    /// Whether `session` is currently active (start inclusive, end
    /// exclusive). If `endTime` is earlier than `startTime`, the window is
    /// treated as spanning midnight into the next day (e.g. 22:00–08:00):
    /// the recurrence rule is always checked against the day the window
    /// *started* on, not the calendar day `date` happens to fall on.
    static func isActive(_ session: FocusSession, at date: Date = .now, calendar: Calendar = .current) -> Bool {
        if session.isOnDemand {
            guard let activeUntil = session.activeUntil else { return false }
            return date < activeUntil
        }

        let currentMinutes = minutesSinceMidnight(of: date, calendar: calendar)
        let startMinutes = minutesSinceMidnight(of: session.startTime, calendar: calendar)
        let endMinutes = minutesSinceMidnight(of: session.endTime, calendar: calendar)

        guard startMinutes != endMinutes else { return false }

        if startMinutes < endMinutes {
            guard currentMinutes >= startMinutes && currentMinutes < endMinutes else { return false }
            return RecurrenceEngine.isScheduled(session.recurrenceRule, on: date, calendar: calendar)
        }

        // Overnight window: `date` is either still in the segment after
        // `start` (same day the window started) or already in the segment
        // before `end` (the day after, but the window still "belongs" to
        // the previous day for recurrence purposes).
        if currentMinutes >= startMinutes {
            return RecurrenceEngine.isScheduled(session.recurrenceRule, on: date, calendar: calendar)
        }
        if currentMinutes < endMinutes {
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: date) else { return false }
            return RecurrenceEngine.isScheduled(session.recurrenceRule, on: previousDay, calendar: calendar)
        }
        return false
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
