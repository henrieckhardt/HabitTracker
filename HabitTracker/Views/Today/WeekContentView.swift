import SwiftUI
import SwiftData

/// The week-mode content for `DayContentView` — a 7-day digest, one row per
/// day, each row pushing `DayContentView(allowsDateNavigation: false)` for
/// that specific day. This used to be `WeekView`'s entire body, back when
/// Woche was its own tab with its own `NavigationStack`; it's now hosted
/// inside the Heute tab's stack instead, switched to via `DayContentView`'s
/// segmented control, so it owns neither a `NavigationStack` nor a toolbar
/// of its own — both belong to the parent.
struct WeekContentView: View {
    @Binding var weekAnchor: Date

    @Query(filter: #Predicate<Habit> { !$0.isArchived }, sort: \Habit.createdAt)
    private var allHabits: [Habit]
    @Query(sort: \ToDo.createdAt) private var allToDos: [ToDo]

    @State private var showingQuickAdd = false
    @State private var quickAddDate: Date = .now

    private var calendar: Calendar {
        CalendarProvider.current
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
        // Same reasoning as DayContentView's todayStart: computed once and
        // threaded down instead of every row calling `isDateInToday`
        // independently, so a midnight rollover mid-render can't leave two
        // adjacent rows both "correctly" marked as today.
        let todayStart = calendar.startOfDay(for: .now)

        List {
            Section {
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
            } header: {
                weekHeading
            }
        }
        .sheet(isPresented: $showingQuickAdd) {
            QuickAddToDosView(date: quickAddDate)
        }
    }

    /// Mirrors `DayContentView.dateHeading`'s look (large-title heading atop
    /// the list) but shows the week range instead of a single date, and taps
    /// to jump back to the current week instead of opening a date picker.
    @ViewBuilder
    private var weekHeading: some View {
        Group {
            Button {
                weekAnchor = calendar.startOfDay(for: .now)
            } label: {
                Text(weekRangeText)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
        }
        .textCase(nil)
        .foregroundStyle(.primary)
        .padding(.bottom, 4)
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
