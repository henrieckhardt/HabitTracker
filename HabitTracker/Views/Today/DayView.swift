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

    /// Habits scheduled for `selectedDate`, unsorted — `dayItems` below is
    /// the single place that decides display order, merging these with
    /// `scheduledToDos` by `sortOrder`.
    private var scheduledHabits: [Habit] {
        allHabits.filter { RecurrenceEngine.isScheduled($0.recurrenceRule, on: selectedDate, calendar: calendar) }
    }

    private var scheduledToDos: [ToDo] {
        allToDos.filter { calendar.isDate($0.scheduledDate, inSameDayAs: selectedDate) }
    }

    /// Habits and to-dos merged into one manually-orderable list. Sorted by
    /// `sortOrder` first (the user's drag-and-drop order, shared across both
    /// types), then completed items are stably sunk to the bottom, keeping
    /// their relative order otherwise.
    private var dayItems: [DayItem] {
        let habits = scheduledHabits.map { DayItem.habit($0, isCompleted: $0.isCompleted(on: selectedDate, calendar: calendar)) }
        let toDos = scheduledToDos.map { DayItem.toDo($0) }
        return (habits + toDos)
            .sorted { $0.sortOrder < $1.sortOrder }
            .sorted { !$0.isCompleted && $1.isCompleted }
    }

    var body: some View {
        List {
            if dayItems.isEmpty {
                ContentUnavailableView(
                    "Nothing planned",
                    systemImage: "checkmark.circle",
                    description: Text("There are no habits or to-dos scheduled for this day.")
                )
                .listRowSeparator(.hidden)
            } else {
                ForEach(dayItems) { item in
                    DayItemRow(item: item, date: selectedDate)
                        .swipeActions(edge: .trailing) {
                            if case .toDo(let toDo) = item {
                                Button(role: .destructive) {
                                    deleteToDo(toDo)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    moveToTomorrow(toDo)
                                } label: {
                                    Label("Tomorrow", systemImage: "arrow.right")
                                }
                                .tint(.orange)

                                Button {
                                    toDoToMove = toDo
                                } label: {
                                    Label("Move", systemImage: "calendar")
                                }
                                .tint(.blue)
                            }
                        }
                }
                .onMove(perform: moveDayItems)
            }
        }
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                DateHeader(selectedDate: $selectedDate)
            }
            ToolbarItem(placement: .primaryAction) {
                if !dayItems.isEmpty {
                    EditButton()
                }
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

    /// Persists a drag-and-drop reorder by giving the moved item a
    /// `sortOrder` between its new neighbors — see `DisplayOrderReordering`.
    /// Works across the habit/to-do boundary since both share the same
    /// numeric `sortOrder` space.
    private func moveDayItems(from source: IndexSet, to destination: Int) {
        let currentItems = dayItems
        guard let originalIndex = source.first else { return }
        let movedID = currentItems[originalIndex].id

        var reordered = currentItems
        reordered.move(fromOffsets: source, toOffset: destination)
        guard let newIndex = reordered.firstIndex(where: { $0.id == movedID }) else { return }

        let before = newIndex > 0 ? reordered[newIndex - 1].sortOrder : nil
        let after = newIndex < reordered.count - 1 ? reordered[newIndex + 1].sortOrder : nil
        let newSortOrder = DisplayOrderReordering.newSortOrder(before: before, after: after)

        switch reordered[newIndex] {
        case .habit(let habit, _):
            habit.sortOrder = newSortOrder
        case .toDo(let toDo):
            toDo.sortOrder = newSortOrder
        }
        try? modelContext.save()
    }
}

/// A single row in `DayView`'s unified list — either a `Habit` (with its
/// per-day completion already resolved, since that depends on `date`) or a
/// `ToDo`. Both share one `sortOrder` namespace so they can be freely
/// interleaved and drag-reordered together.
enum DayItem: Identifiable {
    case habit(Habit, isCompleted: Bool)
    case toDo(ToDo)

    var id: String {
        switch self {
        case .habit(let habit, _): "habit-\(habit.id)"
        case .toDo(let toDo): "todo-\(toDo.id)"
        }
    }

    var sortOrder: Double {
        switch self {
        case .habit(let habit, _): habit.sortOrder
        case .toDo(let toDo): toDo.sortOrder
        }
    }

    var isCompleted: Bool {
        switch self {
        case .habit(_, let isCompleted): isCompleted
        case .toDo(let toDo): toDo.isCompleted
        }
    }
}

private struct DateHeader: View {
    @Binding var selectedDate: Date
    @State private var showingDatePicker = false
    private let calendar = Calendar.current

    private var isToday: Bool {
        calendar.isDateInToday(selectedDate)
    }

    private var formatted: String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE d. MMM")
        formatter.locale = .autoupdatingCurrent
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
                Group {
                    if isToday {
                        Text("Today")
                    } else {
                        Text(formatted)
                    }
                }
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
                "Date",
                selection: normalizedSelection,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle("Choose Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Today") {
                        selectedDate = Calendar.current.startOfDay(for: .now)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
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
                DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
            }
            .navigationTitle("Move")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
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

private func habitTimeText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = .autoupdatingCurrent
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter.string(from: date)
}

/// Unified row for `DayView`'s merged habit/to-do list. Habits are visually
/// distinguished only by a small "Habit" badge next to the title (and their
/// optional time-window badge) — otherwise both types share the exact same
/// checkbox-title-notes layout, so they read as one consistent list rather
/// than two different row styles glued together.
private struct DayItemRow: View {
    @Environment(\.modelContext) private var modelContext
    let item: DayItem
    let date: Date

    @State private var showingHabitEditor = false
    @State private var showingToDoEditor = false

    private var title: String {
        switch item {
        case .habit(let habit, _): habit.title
        case .toDo(let toDo): toDo.title
        }
    }

    private var isCompleted: Bool { item.isCompleted }

    /// Time-window badge for a habit with a focus session, or a notes
    /// preview for a to-do — the two types happen to only ever need one
    /// secondary line, never both.
    private var subtitle: String? {
        switch item {
        case .habit(let habit, _):
            guard let session = habit.focusSession else { return nil }
            return "\(habitTimeText(session.startTime))–\(habitTimeText(session.endTime))"
        case .toDo(let toDo):
            guard let notes = toDo.notes, !notes.isEmpty else { return nil }
            return notes
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                toggle()
            } label: {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isCompleted ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)

            Button {
                openEditor()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .strikethrough(isCompleted)
                            .foregroundStyle(isCompleted ? .secondary : .primary)
                        if case .habit = item {
                            habitBadge
                        }
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .sheet(isPresented: $showingHabitEditor) {
            if case .habit(let habit, _) = item {
                HabitEditorView(habit: habit)
            }
        }
        .sheet(isPresented: $showingToDoEditor) {
            if case .toDo(let toDo) = item {
                ToDoEditorView(toDo: toDo)
            }
        }
    }

    private var habitBadge: some View {
        Label("Habit", systemImage: "repeat")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.15))
            .foregroundStyle(Color.accentColor)
            .clipShape(Capsule())
    }

    private func openEditor() {
        switch item {
        case .habit: showingHabitEditor = true
        case .toDo: showingToDoEditor = true
        }
    }

    private func toggle() {
        switch item {
        case .habit(let habit, _):
            if let completion = habit.completion(on: date) {
                modelContext.delete(completion)
            } else {
                let completion = HabitCompletion(date: date, habit: habit)
                modelContext.insert(completion)
            }
        case .toDo(let toDo):
            toDo.isCompleted.toggle()
            toDo.completedAt = toDo.isCompleted ? .now : nil
            if toDo.isCompleted {
                NotificationService.cancelReminder(for: toDo)
            } else if toDo.reminderTime != nil {
                NotificationService.scheduleReminder(for: toDo)
            }
        }
        try? modelContext.save()
    }
}
