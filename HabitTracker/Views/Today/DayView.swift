import SwiftUI
import SwiftData

/// Tab-root wrapper: owns the NavigationStack so the "Heute" tab has its own
/// navigation context, separate from the Woche tab's stack.
struct DayView: View {
    var body: some View {
        NavigationStack {
            DayContentView(initialDate: Calendar.current.startOfDay(for: .now))
        }
    }
}

/// The actual day content (habit/todo lists, date header, add button).
/// Reused as a push destination from WeekView, which supplies its own
/// NavigationStack, so this view must not wrap one itself.
struct DayContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Habit> { !$0.isArchived }, sort: \Habit.createdAt)
    private var allHabits: [Habit]
    @Query(sort: \ToDo.createdAt) private var allToDos: [ToDo]

    @State private var selectedDate: Date
    @State private var showingAddToDo = false
    @State private var showingQuickAdd = false
    @State private var toDoToMove: ToDo?

    private let calendar = Calendar.current

    init(initialDate: Date) {
        _selectedDate = State(initialValue: Calendar.current.startOfDay(for: initialDate))
    }

    private var habitsForDay: [Habit] {
        allHabits.filter { RecurrenceEngine.isScheduled($0.recurrenceRule, on: selectedDate, calendar: calendar) }
    }

    private var toDosForDay: [ToDo] {
        allToDos
            .filter { calendar.isDate($0.scheduledDate, inSameDayAs: selectedDate) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
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
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteToDo(toDo)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }

                            Button {
                                moveToTomorrow(toDo)
                            } label: {
                                Label("Morgen", systemImage: "arrow.right")
                            }
                            .tint(.orange)

                            Button {
                                toDoToMove = toDo
                            } label: {
                                Label("Verschieben", systemImage: "calendar")
                            }
                            .tint(.blue)
                        }
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                DateHeader(selectedDate: $selectedDate)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingQuickAdd = true
                } label: {
                    Image(systemName: "note.text.badge.plus")
                }
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
        .sheet(isPresented: $showingQuickAdd) {
            QuickAddToDosView(date: selectedDate)
        }
        .sheet(item: $toDoToMove) { toDo in
            MoveToDoDateSheet(toDo: toDo)
        }
        .task {
            RolloverService.rolloverIfNeeded(context: modelContext)
        }
    }

    private func deleteToDo(_ toDo: ToDo) {
        NotificationService.cancelReminder(for: toDo)
        modelContext.delete(toDo)
        try? modelContext.save()
    }

    private func moveToTomorrow(_ toDo: ToDo) {
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: toDo.scheduledDate) else { return }
        toDo.scheduledDate = calendar.startOfDay(for: tomorrow)
        if toDo.reminderTime != nil {
            NotificationService.scheduleReminder(for: toDo, calendar: calendar)
        }
        try? modelContext.save()
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

/// Fast single-purpose date picker for moving one ToDo to a different day —
/// deliberately separate from `ToDoEditorView`'s full form, and from
/// `DatePickerSheet` above (which navigates the whole day view, not one
/// ToDo's date).
private struct MoveToDoDateSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let toDo: ToDo
    @State private var selectedDate: Date

    init(toDo: ToDo) {
        self.toDo = toDo
        _selectedDate = State(initialValue: toDo.scheduledDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Datum", selection: $selectedDate, displayedComponents: .date)
            }
            .navigationTitle("Verschieben")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        move(to: selectedDate)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func move(to date: Date) {
        let calendar = Calendar.current
        toDo.scheduledDate = calendar.startOfDay(for: date)
        if toDo.reminderTime != nil {
            NotificationService.scheduleReminder(for: toDo, calendar: calendar)
        }
        try? modelContext.save()
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
    @State private var showingEditor = false

    var body: some View {
        HStack(spacing: 12) {
            Button {
                toggleCompletion()
            } label: {
                Image(systemName: toDo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(toDo.isCompleted ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)

            Button {
                showingEditor = true
            } label: {
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
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .sheet(isPresented: $showingEditor) {
            ToDoEditorView(toDo: toDo)
        }
    }

    private func toggleCompletion() {
        toDo.isCompleted.toggle()
        toDo.completedAt = toDo.isCompleted ? .now : nil
        if toDo.isCompleted {
            NotificationService.cancelReminder(for: toDo)
        } else if toDo.reminderTime != nil {
            NotificationService.scheduleReminder(for: toDo)
        }
        try? modelContext.save()
    }
}
