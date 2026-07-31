import Foundation

enum StreakEngine {
    /// Number of consecutive *scheduled* days, counting back from today,
    /// that were completed. Non-scheduled days are skipped without breaking
    /// the streak. Today doesn't break an in-progress streak even if not yet
    /// completed, since the day isn't over.
    static func currentStreak(for habit: Habit, today: Date = .now, calendar: Calendar = .current) -> Int {
        let todayStart = calendar.startOfDay(for: today)
        let creationStart = calendar.startOfDay(for: habit.createdAt)
        var streak = 0
        var cursor = todayStart

        while cursor >= creationStart {
            if RecurrenceEngine.isScheduled(habit.recurrenceRule, on: cursor, calendar: calendar) {
                if habit.isCompleted(on: cursor, calendar: calendar) {
                    streak += 1
                } else if cursor != todayStart {
                    break
                }
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    /// Longest run of consecutive completed scheduled days between the
    /// habit's creation date and today.
    static func longestStreak(for habit: Habit, today: Date = .now, calendar: Calendar = .current) -> Int {
        let todayStart = calendar.startOfDay(for: today)
        var cursor = calendar.startOfDay(for: habit.createdAt)
        var current = 0
        var longest = 0

        while cursor <= todayStart {
            if RecurrenceEngine.isScheduled(habit.recurrenceRule, on: cursor, calendar: calendar) {
                if habit.isCompleted(on: cursor, calendar: calendar) {
                    current += 1
                    longest = max(longest, current)
                } else if cursor != todayStart {
                    current = 0
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return longest
    }

    /// Fraction of scheduled days that were completed in the last `lastDays`
    /// days (clamped to the habit's creation date if it's younger than that).
    static func completionRate(for habit: Habit, lastDays: Int = 30, today: Date = .now, calendar: Calendar = .current) -> Double {
        let todayStart = calendar.startOfDay(for: today)
        let creationStart = calendar.startOfDay(for: habit.createdAt)
        let earliestPossible = calendar.date(byAdding: .day, value: -(lastDays - 1), to: todayStart) ?? todayStart
        var cursor = max(earliestPossible, creationStart)

        var scheduledCount = 0
        var completedCount = 0
        while cursor <= todayStart {
            if RecurrenceEngine.isScheduled(habit.recurrenceRule, on: cursor, calendar: calendar) {
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
}
