import SwiftUI
import SwiftData

/// Tab-root wrapper: owns the NavigationStack so the "Heute" tab has its own
/// navigation context, separate from the Woche tab's stack.
struct DayView: View {
    var body: some View {
        NavigationStack {
            DayContentView(initialDate: Calendar.current.startOfDay(for: .now), allowsDateNavigation: true)
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
    // Standalone sessions only (`ownerHabit == nil`) — same predicate as
    // `FocusListView`/`StartFocusSheet` — so a habit's own companion window
    // is never mistaken for "the" active focus here.
    @Query(filter: #Predicate<FocusSession> { !$0.isArchived && $0.ownerHabit == nil }, sort: \FocusSession.createdAt)
    private var allFocusSessions: [FocusSession]

    @State private var selectedDate: Date
    @State private var showingAddToDo = false
    @State private var showingQuickAdd = false
    @State private var showingDatePicker = false
    @State private var toDoToMove: ToDo?
    @State private var startFocusItem: DayItem?
    @State private var editMode: EditMode = .inactive

    /// Drives `activeFocusSession` below. Only needs to catch a session's
    /// window *elapsing* while this view sits open — starts/stops made
    /// through the app itself already refresh `allFocusSessions` via
    /// `@Query` the moment they save. Same pattern as `FocusListView`.
    @State private var now: Date = .now
    private let focusTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var activeFocusSession: FocusSession? {
        FocusScheduleEngine.currentlyActiveSession(in: allFocusSessions, at: now)
    }

    /// Whether the day can be changed at all — true for the standalone
    /// "Heute" tab, false when this view is pushed from `WeekView` for a
    /// specific day, which should stay fixed to that day (no chevrons, no
    /// tappable heading, no date picker).
    let allowsDateNavigation: Bool

    private let calendar = Calendar.current

    init(initialDate: Date, allowsDateNavigation: Bool) {
        _selectedDate = State(initialValue: Calendar.current.startOfDay(for: initialDate))
        self.allowsDateNavigation = allowsDateNavigation
    }

    private var isToday: Bool {
        calendar.isDateInToday(selectedDate)
    }

    private var formattedSelectedDate: String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE d. MMM")
        formatter.locale = .autoupdatingCurrent
        return formatter.string(from: selectedDate)
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

    /// Habits and to-dos merged into one list, sorted by `sortOrder` (the
    /// user's drag-and-drop order, shared across both types). `listContent`
    /// below splits this into `incompleteItems`/`completedItems` as two
    /// separate `ForEach`s — completed items always render last and never
    /// get a `.onMove`, so they can neither be dragged themselves nor be a
    /// drop target for an incomplete item dragged past the end of the
    /// incomplete group (previously, with one merged+re-sorted list,
    /// dragging an incomplete item to the very bottom put it after the
    /// completed items only for the completed-sink sort to immediately snap
    /// it back above them, which looked like the drag silently failing).
    private var dayItems: [DayItem] {
        let habits = scheduledHabits.map { DayItem.habit($0, isCompleted: $0.isCompleted(on: selectedDate, calendar: calendar)) }
        let toDos = scheduledToDos.map { DayItem.toDo($0) }
        return (habits + toDos).sorted { $0.sortOrder < $1.sortOrder }
    }

    private var incompleteItems: [DayItem] {
        dayItems.filter { !$0.isCompleted }
    }

    private var completedItems: [DayItem] {
        dayItems.filter { $0.isCompleted }
    }

    var body: some View {
        List {
            Section {
                if dayItems.isEmpty {
                    ContentUnavailableView(
                        "Nothing planned",
                        systemImage: "checkmark.circle",
                        description: Text("There are no habits or to-dos scheduled for this day.")
                    )
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(incompleteItems) { item in
                        row(for: item)
                    }
                    .onMove(perform: moveIncompleteItems)

                    // Separate, non-reorderable `ForEach`: no `.onMove` means no
                    // drag handle and no drag gesture at all for these rows, and
                    // they can never be a destination for an incomplete item
                    // dragged past the end of the section above — completed
                    // items just stay put at the bottom.
                    ForEach(completedItems) { item in
                        row(for: item)
                    }
                }
            } header: {
                dateHeading
            }
        }
        .safeAreaInset(edge: .top) {
            // Deliberately a `safeAreaInset` on the `List`, not a
            // conditional `Section` inside it — see `FocusListView`'s
            // comment on why that broke sibling-row hit testing.
            if let activeFocusSession {
                ActiveFocusBanner(session: activeFocusSession)
                    .padding()
                    .background(.bar)
            }
        }
        .environment(\.editMode, $editMode)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if allowsDateNavigation {
                // `.navigationBarLeading` instead of `.principal`: a
                // `.principal` item is centered in the *remaining* bar
                // width after the leading/trailing items, so it visibly
                // drifted depending on how many trailing buttons were
                // showing (e.g. the pencil button disappearing on an empty
                // day) — pinning to the leading edge keeps it in a fixed
                // spot regardless of what else is in the toolbar.
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 16) {
                        Button {
                            selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                        } label: {
                            Image(systemName: "chevron.left")
                        }

                        Button {
                            selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                if !dayItems.isEmpty {
                    Button {
                        withAnimation {
                            editMode = editMode == .active ? .inactive : .active
                        }
                    } label: {
                        Image(systemName: editMode == .active ? "checkmark" : "pencil")
                    }
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
        .sheet(isPresented: $showingDatePicker) {
            DatePickerSheet(selectedDate: $selectedDate)
        }
        .sheet(item: $startFocusItem) { item in
            switch item {
            case .habit(let habit, _):
                StartFocusSheet(itemTitle: habit.title, linkedToDo: nil, linkedHabit: habit)
            case .toDo(let toDo):
                StartFocusSheet(itemTitle: toDo.title, linkedToDo: toDo, linkedHabit: nil)
            }
        }
        .task {
            RolloverService.rolloverIfNeeded(context: modelContext)
        }
        .onReceive(focusTimer) { date in
            now = date
        }
    }

    /// The list's heading — replaces what used to be a "Heute"/date label in
    /// the navigation bar. Tappable to open the graphical date picker only
    /// when `allowsDateNavigation` is true; fixed, non-interactive text
    /// otherwise (the day pushed from `WeekView` never changes).
    @ViewBuilder
    private var dateHeading: some View {
        let text = Group {
            if isToday {
                Text("Today")
            } else {
                Text(formattedSelectedDate)
            }
        }
        .font(.largeTitle.bold())
        .foregroundStyle(.primary)

        Group {
            if allowsDateNavigation {
                Button {
                    showingDatePicker = true
                } label: {
                    text
                }
                .buttonStyle(.plain)
            } else {
                text
            }
        }
        .textCase(nil)
        .foregroundStyle(.primary)
        .padding(.bottom, 4)
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

    @ViewBuilder
    private func row(for item: DayItem) -> some View {
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
            .swipeActions(edge: .leading) {
                Button {
                    startFocusItem = item
                } label: {
                    Label("Focus", systemImage: "timer")
                }
                .tint(.indigo)
            }
    }

    /// Persists a drag-and-drop reorder by giving the moved item a
    /// `sortOrder` between its new neighbors — see `DisplayOrderReordering`.
    /// Works across the habit/to-do boundary since both share the same
    /// numeric `sortOrder` space. Operates only on `incompleteItems` (see
    /// its `ForEach` in `listContent`), so there's no completed-items
    /// boundary to bounce off of — the moved item's neighbors are always
    /// other incomplete items, or nothing at either end of the section.
    /// Uses the system `.onMove` reorder, which needs edit mode active to
    /// show drag handles/respond to drag gestures on rows with their own
    /// tap-consuming Buttons — driven here by the icon-only toolbar button
    /// toggling `editMode`, rather than a permanently-active edit mode,
    /// since edit mode disables trailing `.swipeActions` (the per-ToDo
    /// Delete/Tomorrow/Move actions), so the list needs to leave edit mode
    /// again for those to be reachable.
    private func moveIncompleteItems(from source: IndexSet, to destination: Int) {
        let currentItems = incompleteItems
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
