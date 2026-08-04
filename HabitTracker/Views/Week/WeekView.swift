import SwiftUI
import SwiftData

struct WeekView: View {
    @Query(filter: #Predicate<Habit> { !$0.isArchived }, sort: \Habit.createdAt)
    private var allHabits: [Habit]
    @Query(sort: \ToDo.createdAt) private var allToDos: [ToDo]

    @State private var weekAnchor: Date = Calendar.current.startOfDay(for: .now)

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday, matching WeekdaySelector's ordering.
        return cal
    }

    private var daysInWeek: [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: weekAnchor) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    private var weekRangeText: String {
        guard let first = daysInWeek.first, let last = daysInWeek.last else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.setLocalizedDateFormatFromTemplate("d. MMM")
        return "\(formatter.string(from: first)) – \(formatter.string(from: last))"
    }

    private func habitsForDay(_ date: Date) -> [Habit] {
        allHabits.filter { RecurrenceEngine.isScheduled($0.recurrenceRule, on: date, calendar: calendar) }
    }

    private func toDosForDay(_ date: Date) -> [ToDo] {
        allToDos.filter { calendar.isDate($0.scheduledDate, inSameDayAs: date) }
    }

    var body: some View {
        // Computed once per render and threaded down, instead of every row
        // independently calling `calendar.isDateInToday(date)` — with 7
        // separate calls, list rows built at slightly different times (e.g.
        // while scrolling) could straddle a midnight rollover and each
        // "correctly" see a different `Date()`, so two adjacent days both
        // ended up marked "Heute". A single shared reference makes that
        // structurally impossible.
        let todayStart = calendar.startOfDay(for: .now)

        NavigationStack {
            List {
                ForEach(daysInWeek, id: \.self) { date in
                    NavigationLink(value: date) {
                        WeekDayRow(
                            date: date,
                            calendar: calendar,
                            isToday: calendar.isDate(date, inSameDayAs: todayStart),
                            habits: habitsForDay(date),
                            toDos: toDosForDay(date)
                        )
                    }
                }
            }
            .navigationTitle("Woche")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 16) {
                        Button {
                            weekAnchor = calendar.date(byAdding: .day, value: -7, to: weekAnchor) ?? weekAnchor
                        } label: {
                            Image(systemName: "chevron.left")
                        }

                        Button {
                            weekAnchor = calendar.startOfDay(for: .now)
                        } label: {
                            Text(weekRangeText)
                                .font(.headline)
                        }
                        .buttonStyle(.plain)

                        Button {
                            weekAnchor = calendar.date(byAdding: .day, value: 7, to: weekAnchor) ?? weekAnchor
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                    }
                }
            }
            .navigationDestination(for: Date.self) { date in
                DayContentView(initialDate: date)
            }
        }
    }
}

private struct WeekDayRow: View {
    let date: Date
    let calendar: Calendar
    let isToday: Bool
    let habits: [Habit]
    let toDos: [ToDo]

    private var weekdayLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.setLocalizedDateFormatFromTemplate("EEEE, d. MMM")
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(weekdayLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isToday ? Color.accentColor : .primary)
                if isToday {
                    Text("Heute")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }
            }

            if habits.isEmpty && toDos.isEmpty {
                Text("Nichts geplant")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(habits) { habit in
                        let completed = habit.isCompleted(on: date, calendar: calendar)
                        Label {
                            Text(habit.title)
                                .strikethrough(completed)
                        } icon: {
                            Image(systemName: habit.icon)
                        }
                        .font(.caption)
                        .foregroundStyle(completed ? .secondary : .primary)
                    }
                    ForEach(toDos) { toDo in
                        Label {
                            Text(toDo.title)
                                .strikethrough(toDo.isCompleted)
                        } icon: {
                            Image(systemName: "checklist")
                        }
                        .font(.caption)
                        .foregroundStyle(toDo.isCompleted ? .secondary : .primary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
