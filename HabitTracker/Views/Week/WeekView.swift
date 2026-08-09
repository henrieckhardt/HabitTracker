import SwiftUI
import SwiftData

struct WeekView: View {
    @Query(filter: #Predicate<Habit> { !$0.isArchived }, sort: \Habit.createdAt)
    private var allHabits: [Habit]
    @Query(sort: \ToDo.createdAt) private var allToDos: [ToDo]

    @State private var weekAnchor: Date = Calendar.current.startOfDay(for: .now)
    @State private var showingQuickAdd = false
    @State private var quickAddDate: Date = .now

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
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("d. MMM")
        return "\(formatter.string(from: first)) – \(formatter.string(from: last))"
    }

    private func habitsForDay(_ date: Date) -> [Habit] {
        let scheduled = allHabits.filter { RecurrenceEngine.isScheduled($0.recurrenceRule, on: date, calendar: calendar) }
        return HabitDisplayOrdering.sortedForDay(scheduled, calendar: calendar)
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
                    .swipeActions(edge: .leading) {
                        Button {
                            quickAddDate = date
                            showingQuickAdd = true
                        } label: {
                            Label("Add", systemImage: "note.text.badge.plus")
                        }
                        .tint(.blue)
                    }
                }
            }
            .navigationTitle("Week")
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
            .sheet(isPresented: $showingQuickAdd) {
                QuickAddToDosView(date: quickAddDate)
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
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("EEEE, d. MMM")
        return formatter.string(from: date)
    }

    private func habitLabelText(_ habit: Habit) -> String {
        guard let session = habit.focusSession else { return habit.title }
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        let start = formatter.string(from: session.startTime)
        return "\(habit.title) · \(start)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(weekdayLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isToday ? Color.accentColor : .primary)
                if isToday {
                    Text("Today")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }
            }

            if habits.isEmpty && toDos.isEmpty {
                Text("Nothing planned")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(habits) { habit in
                        let completed = habit.isCompleted(on: date, calendar: calendar)
                        Label {
                            Text(habitLabelText(habit))
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
                            Image(systemName: toDo.isCompleted ? "checkmark.circle" : "circle")
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
