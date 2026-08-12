import Foundation

/// Cross-habit / cross-to-do numbers for `ProfileView`'s weekly summary —
/// the counterpart to `StreakEngine` (which is always about one habit) and
/// `FocusStatsEngine` (always about `FocusRun`s).
enum AggregateStatsEngine {
    struct ToDoStats: Equatable {
        let completed: Int
        let total: Int
    }

    /// Fraction of `date`'s scheduled habits that are completed. `0` if
    /// nothing is scheduled that day (not `nil`/`NaN` — an empty day reads
    /// as "0% done" rather than needing special-cased display logic).
    static func todayProgress(habits: [Habit], on date: Date = .now, calendar: Calendar = .current) -> Double {
        let scheduled = habits.filter { RecurrenceEngine.isScheduled($0.recurrenceRule, on: date, calendar: calendar) }
        guard !scheduled.isEmpty else { return 0 }
        let completed = scheduled.filter { $0.isCompleted(on: date, calendar: calendar) }.count
        return Double(completed) / Double(scheduled.count)
    }

    /// Fraction of scheduled-habit-days completed across the calendar week
    /// containing `date`, counting only up through `date` itself — days
    /// later in the week haven't happened yet and must not be counted as
    /// missed just because they're unscheduled-so-far.
    static func weekCompletionRate(habits: [Habit], containing date: Date = .now, calendar: Calendar = .current) -> Double {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return 0 }
        let todayStart = calendar.startOfDay(for: date)

        var scheduledCount = 0
        var completedCount = 0
        var cursor = calendar.startOfDay(for: interval.start)
        while cursor <= todayStart && cursor < interval.end {
            for habit in habits where RecurrenceEngine.isScheduled(habit.recurrenceRule, on: cursor, calendar: calendar) {
                scheduledCount += 1
                if habit.isCompleted(on: cursor, calendar: calendar) {
                    completedCount += 1
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        guard scheduledCount > 0 else { return 0 }
        return Double(completedCount) / Double(scheduledCount)
    }

    /// Completed vs. total to-dos scheduled for `date`.
    static func toDoStats(toDos: [ToDo], on date: Date = .now, calendar: Calendar = .current) -> ToDoStats {
        let scheduledToday = toDos.filter { calendar.isDate($0.scheduledDate, inSameDayAs: date) }
        return ToDoStats(completed: scheduledToday.filter(\.isCompleted).count, total: scheduledToday.count)
    }

    /// The single longest current streak among `habits` — a headline number
    /// ("your best streak right now is N days") rather than a per-habit
    /// breakdown.
    static func bestCurrentStreak(habits: [Habit], today: Date = .now, calendar: Calendar = .current) -> Int {
        habits.map { StreakEngine.currentStreak(for: $0, today: today, calendar: calendar) }.max() ?? 0
    }
}
