import SwiftUI
import SwiftData
import FamilyControls

struct HabitEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// nil when creating a new habit.
    private let habitToEdit: Habit?

    @State private var title: String
    @State private var icon: String
    @State private var recurrenceState: RecurrenceEditorState
    @State private var reminderEnabled: Bool
    @State private var reminderTime: Date

    @State private var windowEnabled: Bool
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var blockingEnabled: Bool
    @State private var appSelection: FamilyActivitySelection
    @State private var showingActivityPicker = false
    @State private var isRequestingAuthorization = false
    @State private var authorizationDeniedAlert = false

    private static let iconChoices = [
        "checkmark.circle", "flame", "figure.run", "book", "drop",
        "bed.double", "leaf", "cup.and.saucer", "dumbbell", "pills",
        "moon.stars", "sun.max", "heart", "brain.head.profile", "sparkles"
    ]

    private static var defaultReminderTime: Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
    }

    private static var defaultWindowStart: Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
    }

    private static var defaultWindowEnd: Date {
        Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: .now) ?? .now
    }

    init(habit: Habit? = nil) {
        self.habitToEdit = habit
        _title = State(initialValue: habit?.title ?? "")
        _icon = State(initialValue: habit?.icon ?? "checkmark.circle")
        _recurrenceState = State(initialValue: RecurrenceEditorState.from(habit?.recurrenceRule ?? .daily))
        _reminderEnabled = State(initialValue: habit?.reminderTime != nil)
        _reminderTime = State(initialValue: habit?.reminderTime ?? Self.defaultReminderTime)

        let focusSession = habit?.focusSession
        _windowEnabled = State(initialValue: focusSession != nil)
        _startTime = State(initialValue: focusSession?.startTime ?? Self.defaultWindowStart)
        _endTime = State(initialValue: focusSession?.endTime ?? Self.defaultWindowEnd)
        _blockingEnabled = State(initialValue: focusSession?.isBlockingEnabled ?? false)
        _appSelection = State(initialValue: focusSession?.blockedSelection ?? FamilyActivitySelection())
    }

    /// Only the hour/minute of `startTime`/`endTime` matter. Mirrors
    /// `FocusEditorView`'s identical validation — an end time earlier than
    /// the start time is a window spanning midnight. Windows shorter than
    /// `FocusBlockingScheduler.minimumWindowMinutes` (including exactly
    /// zero-length) are rejected — anything shorter fails
    /// `DeviceActivityCenter` registration outright.
    private var isTimeRangeValid: Bool {
        windowDurationMinutes >= FocusBlockingScheduler.minimumWindowMinutes
    }

    private var windowDurationMinutes: Int {
        let start = minutes(of: startTime)
        let end = minutes(of: endTime)
        guard start != end else { return 0 }
        return end > start ? end - start : (24 * 60 - start) + end
    }

    private var isOvernight: Bool {
        minutes(of: endTime) < minutes(of: startTime)
    }

    private func minutes(of date: Date) -> Int {
        let calendar = Calendar.current
        return calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }

    private var selectionSummary: String {
        let count = appSelection.applicationTokens.count + appSelection.categoryTokens.count
        return count == 0 ? "Keine ausgewählt" : "\(count) ausgewählt"
    }

    private func requestAuthorizationThenShowPicker() {
        isRequestingAuthorization = true
        Task {
            let granted = await FamilyControlsService.requestAuthorization()
            isRequestingAuthorization = false
            if granted {
                showingActivityPicker = true
            } else {
                blockingEnabled = false
                authorizationDeniedAlert = true
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("z.B. Bad putzen", text: $title)
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(Self.iconChoices, id: \.self) { name in
                            Image(systemName: name)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(icon == name ? Color.accentColor.opacity(0.2) : Color.clear)
                                .clipShape(Circle())
                                .onTapGesture { icon = name }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Wiederholung") {
                    RecurrencePickerView(state: $recurrenceState)
                }

                ReminderToggleSection(isEnabled: $reminderEnabled, time: $reminderTime)

                Section {
                    Button {
                        windowEnabled.toggle()
                    } label: {
                        HStack {
                            Text("Zeitfenster aktivieren")
                                .foregroundStyle(.primary)
                            Spacer()
                            Toggle("", isOn: $windowEnabled)
                                .labelsHidden()
                                .allowsHitTesting(false)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if windowEnabled {
                        DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                        DatePicker("Ende", selection: $endTime, displayedComponents: .hourAndMinute)
                        if !isTimeRangeValid {
                            Text("Das Zeitfenster muss mindestens \(FocusBlockingScheduler.minimumWindowMinutes) Minuten lang sein.")
                                .font(.caption)
                                .foregroundStyle(.red)
                        } else if isOvernight {
                            Text("Läuft über Mitternacht bis zum nächsten Tag.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Zeitfenster")
                } footer: {
                    Text("Optional: Uhrzeit, zu der dieser Habit ausgeführt wird. Wird in Tages-/Wochenansicht angezeigt und kann zusätzlich Apps während des Zeitfensters blockieren.")
                }

                if windowEnabled {
                    Section {
                        Toggle("Apps blockieren", isOn: $blockingEnabled)
                            .onChange(of: blockingEnabled) { _, enabled in
                                guard enabled else { return }
                                if FamilyControlsService.isAuthorized {
                                    showingActivityPicker = true
                                } else {
                                    requestAuthorizationThenShowPicker()
                                }
                            }
                        if blockingEnabled {
                            Button {
                                showingActivityPicker = true
                            } label: {
                                HStack {
                                    Text("Ausgewählte Apps")
                                    Spacer()
                                    Text(selectionSummary)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text("App-Blockierung")
                    } footer: {
                        Text("Die ausgewählten Apps werden während des Zeitfensters blockiert und zeigen einen Sperrbildschirm.")
                    }
                }
            }
            .navigationTitle(habitToEdit == nil ? "Neuer Habit" : "Habit bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }
                        .disabled(
                            title.trimmingCharacters(in: .whitespaces).isEmpty
                                || !recurrenceState.isValid
                                || (windowEnabled && !isTimeRangeValid)
                        )
                }
            }
            .familyActivityPicker(isPresented: $showingActivityPicker, selection: $appSelection)
            .alert("Zugriff nicht erlaubt", isPresented: $authorizationDeniedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Ohne Bildschirmzeit-Zugriff können keine Apps blockiert werden. Du kannst das in den Einstellungen unter Bildschirmzeit erlauben.")
            }
        }
    }

    private func save() {
        let rule = recurrenceState.buildRule()
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let newReminderTime = reminderEnabled ? reminderTime : nil

        let habit: Habit
        if let existingHabit = habitToEdit {
            habit = existingHabit
            habit.title = trimmedTitle
            habit.icon = icon
            habit.recurrenceRule = rule
        } else {
            habit = Habit(title: trimmedTitle, icon: icon, recurrenceRule: rule)
            modelContext.insert(habit)
        }
        habit.reminderTime = newReminderTime

        if newReminderTime != nil {
            NotificationService.scheduleReminders(for: habit)
        } else {
            NotificationService.cancelReminders(for: habit)
        }

        syncFocusSession(for: habit, rule: rule, trimmedTitle: trimmedTitle)

        try? modelContext.save()
        dismiss()
    }

    /// Keeps the habit's companion `FocusSession` (its optional time window
    /// + app blocking) in lockstep with the habit's own title/recurrence —
    /// it's never independently editable, so there's no risk of the two
    /// drifting apart or the user managing a duplicate recurrence rule.
    private func syncFocusSession(for habit: Habit, rule: RecurrenceRule, trimmedTitle: String) {
        guard windowEnabled else {
            if let existing = habit.focusSession {
                FocusBlockingScheduler.stop(existing)
                habit.focusSession = nil
                modelContext.delete(existing)
            }
            return
        }

        let selection = blockingEnabled ? appSelection : nil
        let session: FocusSession
        if let existing = habit.focusSession {
            existing.title = trimmedTitle
            existing.startTime = startTime
            existing.endTime = endTime
            existing.recurrenceRule = rule
            existing.blockedSelection = selection
            session = existing
        } else {
            session = FocusSession(
                title: trimmedTitle,
                startTime: startTime,
                endTime: endTime,
                recurrenceRule: rule,
                blockedSelection: selection
            )
            modelContext.insert(session)
            session.ownerHabit = habit
            habit.focusSession = session
        }
        FocusBlockingScheduler.reschedule(session)
    }
}
