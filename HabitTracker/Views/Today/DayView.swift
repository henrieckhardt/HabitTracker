import SwiftUI
import SwiftData

struct DayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Habit> { !$0.isArchived }, sort: \Habit.createdAt)
    private var allHabits: [Habit]
    @Query(sort: \ToDo.createdAt) private var allToDos: [ToDo]

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: .now)
    @State private var showingAddToDo = false

    private let calendar = Calendar.current

    private var habitsForDay: [Habit] {
        allHabits.filter { RecurrenceEngine.isScheduled($0.recurrenceRule, on: selectedDate, calendar: calendar) }
    }

    private var toDosForDay: [ToDo] {
        allToDos
            .filter { calendar.isDate($0.scheduledDate, inSameDayAs: selectedDate) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            List {
                if !habitsForDay.isEmpty {
                    Section("Habits") {
                        ForEach(habitsForDay) { habit in
                            HabitCompletionRow(habit: habit, date: selectedDate)
                        }
                    }
                }

                Section("ToDos") {
                    if toDosForDay.isEmpty {
                        Text("Keine ToDos für diesen Tag.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(toDosForDay) { toDo in
                        ToDoRow(toDo: toDo)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            modelContext.delete(toDosForDay[index])
                        }
                        try? modelContext.save()
                    }
                }

                if habitsForDay.isEmpty && toDosForDay.isEmpty {
                    ContentUnavailableView(
                        "Nichts geplant",
                        systemImage: "checkmark.circle",
                        description: Text("Für diesen Tag stehen keine Habits oder ToDos an.")
                    )
                    .listRowSeparator(.hidden)
                }
            }
            .navigationTitle("Heute")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    DateHeader(selectedDate: $selectedDate)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddToDo = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddToDo) {
                ToDoEditorView(defaultDate: selectedDate)
            }
            .task {
                RolloverService.rolloverIfNeeded(context: modelContext)
            }
        }
    }
}

private struct DateHeader: View {
    @Binding var selectedDate: Date
    @State private var showingDatePicker = false
    private let calendar = Calendar.current

    private var formatted: String {
        if calendar.isDateInToday(selectedDate) {
            return "Heute"
        }
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE d. MMM")
        formatter.locale = Locale(identifier: "de_DE")
        return formatter.string(from: selectedDate)
    }

    var body: some View {
        HStack(spacing: 16) {
            Button {
                selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.left")
            }

            Button {
                showingDatePicker = true
            } label: {
                Text(formatted)
                    .font(.headline)
                    .frame(minWidth: 100)
            }
            .buttonStyle(.plain)

            Button {
                selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            DatePickerSheet(selectedDate: $selectedDate)
        }
    }
}

private struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss

    /// Normalizes whatever the graphical picker returns down to the start of
    /// the day, since the rest of the app compares dates at day granularity.
    private var normalizedSelection: Binding<Date> {
        Binding(
            get: { selectedDate },
            set: { selectedDate = Calendar.current.startOfDay(for: $0) }
        )
    }

    var body: some View {
        NavigationStack {
            DatePicker(
                "Datum",
                selection: normalizedSelection,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle("Datum wählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Heute") {
                        selectedDate = Calendar.current.startOfDay(for: .now)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct HabitCompletionRow: View {
    @Environment(\.modelContext) private var modelContext
    let habit: Habit
    let date: Date

    private var isCompleted: Bool {
        habit.isCompleted(on: date)
    }

    var body: some View {
        Button {
            toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isCompleted ? Color.accentColor : Color.secondary)
                Image(systemName: habit.icon)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24)
                Text(habit.title)
                    .strikethrough(isCompleted)
                    .foregroundStyle(isCompleted ? .secondary : .primary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggle() {
        if let completion = habit.completion(on: date) {
            modelContext.delete(completion)
        } else {
            let completion = HabitCompletion(date: date, habit: habit)
            modelContext.insert(completion)
        }
        try? modelContext.save()
    }
}

private struct ToDoRow: View {
    @Environment(\.modelContext) private var modelContext
    let toDo: ToDo

    var body: some View {
        Button {
            toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: toDo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(toDo.isCompleted ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(toDo.title)
                        .strikethrough(toDo.isCompleted)
                        .foregroundStyle(toDo.isCompleted ? .secondary : .primary)
                    if let notes = toDo.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggle() {
        toDo.isCompleted.toggle()
        toDo.completedAt = toDo.isCompleted ? .now : nil
        try? modelContext.save()
    }
}
