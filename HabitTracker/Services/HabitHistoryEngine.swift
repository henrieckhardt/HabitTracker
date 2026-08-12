import Foundation

/// Builds the day-by-day grid behind `HabitHistoryGridView` — a GitHub-
/// contribution-style visualization of a habit's recent history.
enum HabitHistoryEngine {
    enum DayState: Hashable {
        case completed
        case missed
        case notScheduled
        /// Distinct from `.missed`: `StreakEngine` already clamps its
        /// counting to `habit.createdAt` (a day before creation was never
        /// "missed", the habit didn't exist yet) — a grid that painted
        /// those days as missed would directly contradict the streak
        /// numbers shown right above it.
        case beforeCreation
        case future
    }

    struct DayCell: Hashable {
        let date: Date
        let state: DayState
    }

    /// Column-major: the outer array is weeks (oldest first), each inner
    /// array the 7 days of that week starting on `calendar.firstWeekday`.
    /// The grid always ends on the week containing `endingOn` — the last
    /// cell is never later than `endingOn` itself, which becomes `.future`
    /// for any day after it within that final week.
    static func grid(for habit: Habit, weeks: Int = 12, endingOn: Date = .now, calendar: Calendar = .current) -> [[DayCell]] {
        guard weeks > 0 else { return [] }

        let todayStart = calendar.startOfDay(for: endingOn)
        let creationStart = calendar.startOfDay(for: habit.createdAt)

        guard let currentWeekInterval = calendar.dateInterval(of: .weekOfYear, for: todayStart),
              let firstWeekStart = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: currentWeekInterval.start)
        else { return [] }

        var result: [[DayCell]] = []
        var weekStart = firstWeekStart

        for _ in 0..<weeks {
            var week: [DayCell] = []
            for dayOffset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { continue }
                let dayStart = calendar.startOfDay(for: date)
                week.append(DayCell(date: dayStart, state: state(for: habit, on: dayStart, todayStart: todayStart, creationStart: creationStart, calendar: calendar)))
            }
            result.append(week)
            guard let nextWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) else { break }
            weekStart = nextWeekStart
        }

        return result
    }

    private static func state(
        for habit: Habit,
        on dayStart: Date,
        todayStart: Date,
        creationStart: Date,
        calendar: Calendar
    ) -> DayState {
        if dayStart > todayStart {
            return .future
        }
        if dayStart < creationStart {
            return .beforeCreation
        }
        guard RecurrenceEngine.isScheduled(habit.recurrenceRule, on: dayStart, calendar: calendar) else {
            return .notScheduled
        }
        return habit.isCompleted(on: dayStart, calendar: calendar) ? .completed : .missed
    }
}
