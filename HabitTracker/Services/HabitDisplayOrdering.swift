import Foundation

/// Orders habits for display in `DayView`/`WeekView`: habits without a time
/// window keep their existing creation-order behavior and come first;
/// habits with a linked `focusSession` time window follow, sorted ascending
/// by start time (all-day-before-timed, matching Calendar/Reminders
/// conventions).
enum HabitDisplayOrdering {
    static func sortedForDay(_ habits: [Habit], calendar: Calendar = .current) -> [Habit] {
        let untimed = habits.filter { $0.focusSession == nil }
        let timed = habits
            .filter { $0.focusSession != nil }
            .sorted { minutesSinceMidnight(of: $0, calendar: calendar) < minutesSinceMidnight(of: $1, calendar: calendar) }
        return untimed + timed
    }

    private static func minutesSinceMidnight(of habit: Habit, calendar: Calendar) -> Int {
        guard let startTime = habit.focusSession?.startTime else { return 0 }
        let comps = calendar.dateComponents([.hour, .minute], from: startTime)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }
}
