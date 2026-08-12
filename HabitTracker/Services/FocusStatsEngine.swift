import Foundation

/// Pure statistics over recorded `FocusRun`s — the counterpart to
/// `StreakEngine` for habits, but for focus time instead of completions.
enum FocusStatsEngine {
    /// Minutes of `run` that fall within `day`, clipped to that day's
    /// boundaries. A run isn't necessarily fully inside one calendar day —
    /// `FocusScheduleEngine` explicitly supports overnight windows (e.g.
    /// 23:30–00:30), and a still-open run's live end keeps moving — so this
    /// intersects `[startedAt, effectiveEnd]` with `[day, day+1)` rather
    /// than crediting the whole run to whichever day it started on.
    static func minutes(of run: FocusRun, on day: Date, calendar: Calendar = .current, now: Date = .now) -> Int {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return 0 }

        let overlapStart = max(run.startedAt, dayStart)
        let overlapEnd = min(effectiveEnd(of: run, now: now), dayEnd)
        guard overlapEnd > overlapStart else { return 0 }
        return Int(overlapEnd.timeIntervalSince(overlapStart) / 60)
    }

    static func minutes(in runs: [FocusRun], on day: Date, calendar: Calendar = .current, now: Date = .now) -> Int {
        runs.reduce(0) { $0 + minutes(of: $1, on: day, calendar: calendar, now: now) }
    }

    /// One entry per day in `interval`, oldest first.
    static func minutesPerDay(
        _ runs: [FocusRun],
        in interval: DateInterval,
        calendar: Calendar = .current,
        now: Date = .now
    ) -> [(day: Date, minutes: Int)] {
        var result: [(day: Date, minutes: Int)] = []
        var day = calendar.startOfDay(for: interval.start)
        let end = calendar.startOfDay(for: interval.end) // exclusive — `dateInterval(of:for:)`'s end is the start of the *next* period.

        while day < end {
            result.append((day, minutes(in: runs, on: day, calendar: calendar, now: now)))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    /// Total minutes across the calendar week containing `date`, honoring
    /// `calendar.firstWeekday` (see `CalendarProvider`) rather than assuming
    /// any particular start-of-week.
    static func weekMinutes(_ runs: [FocusRun], containing date: Date, calendar: Calendar = .current, now: Date = .now) -> Int {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return 0 }
        return minutesPerDay(runs, in: interval, calendar: calendar, now: now).reduce(0) { $0 + $1.minutes }
    }

    /// Splits every *closed* run (open ones are still in progress, neither
    /// outcome yet) into reached-its-planned-end vs. stopped-early.
    static func outcomes(_ runs: [FocusRun]) -> (completed: Int, endedEarly: Int) {
        let closed = runs.filter { $0.endedAt != nil }
        let endedEarly = closed.filter(\.wasEndedEarly).count
        return (completed: closed.count - endedEarly, endedEarly: endedEarly)
    }

    /// Total minutes of focus time linked to a given habit (via
    /// `FocusRun.linkedHabitID` — see the Focus↔task linking work), for a
    /// "N min fokussiert" line on that habit's detail screen.
    static func minutes(_ runs: [FocusRun], forHabit id: UUID, now: Date = .now) -> Int {
        runs
            .filter { $0.linkedHabitID == id }
            .reduce(0) { total, run in
                let end = effectiveEnd(of: run, now: now)
                guard end > run.startedAt else { return total }
                return total + Int(end.timeIntervalSince(run.startedAt) / 60)
            }
    }

    /// A closed run's authoritative end is `endedAt`. An open run's live
    /// end is "as far as it's gotten so far, capped at its planned end" —
    /// so "today" totals climb in real time without ever crediting time
    /// that hasn't happened yet.
    private static func effectiveEnd(of run: FocusRun, now: Date) -> Date {
        run.endedAt ?? min(now, run.plannedEnd)
    }
}
