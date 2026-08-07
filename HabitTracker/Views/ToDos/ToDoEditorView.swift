import SwiftUI
import SwiftData

struct ToDoEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// nil when creating a new ToDo.
    private let toDoToEdit: ToDo?

    @State private var title: String
    @State private var notes: String
    @State private var scheduledDate: Date
    @State private var reminderEnabled: Bool
    @State private var reminderTime: Date

    @State private var timeEnabled: Bool
    @State private var startTime: Date
    @State private var endTimeEnabled: Bool
    @State private var endTime: Date

    private static var defaultReminderTime: Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
    }

    private static var defaultStartTime: Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
    }

    private static var defaultEndTime: Date {
        Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: .now) ?? .now
    }

    init(toDo: ToDo? = nil, defaultDate: Date = Calendar.current.startOfDay(for: .now)) {
        self.toDoToEdit = toDo
        _title = State(initialValue: toDo?.title ?? "")
        _notes = State(initialValue: toDo?.notes ?? "")
        _scheduledDate = State(initialValue: toDo?.scheduledDate ?? defaultDate)
        _reminderEnabled = State(initialValue: toDo?.reminderTime != nil)
        _reminderTime = State(initialValue: toDo?.reminderTime ?? Self.defaultReminderTime)

        _timeEnabled = State(initialValue: toDo?.startTime != nil)
        _startTime = State(initialValue: toDo?.startTime ?? Self.defaultStartTime)
        _endTimeEnabled = State(initialValue: toDo?.endTime != nil)
        _endTime = State(initialValue: toDo?.endTime ?? Self.defaultEndTime)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("e.g. Take the car in for inspection", text: $title)
                }
                Section("Notes") {
                    TextField("Optional", text: $notes, axis: .vertical)
                }
                Section("Due On") {
                    DatePicker("Date", selection: $scheduledDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                }

                ReminderToggleSection(isEnabled: $reminderEnabled, time: $reminderTime)

                Section {
                    Button {
                        timeEnabled.toggle()
                    } label: {
                        HStack {
                            Text("Set Time")
                                .foregroundStyle(.primary)
                            Spacer()
                            Toggle("", isOn: $timeEnabled)
                                .labelsHidden()
                                .allowsHitTesting(false)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if timeEnabled {
                        DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)

                        Button {
                            endTimeEnabled.toggle()
                        } label: {
                            HStack {
                                Text("Set End Time")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Toggle("", isOn: $endTimeEnabled)
                                    .labelsHidden()
                                    .allowsHitTesting(false)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if endTimeEnabled {
                            DatePicker("End", selection: $endTime, displayedComponents: .hourAndMinute)
                        }
                    }
                } header: {
                    Text("Time")
                } footer: {
                    Text("Informational only — no reminder or app blocking.")
                }
            }
            .navigationTitle(toDoToEdit == nil ? Text("New To-Do") : Text("Edit To-Do"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)
        let newReminderTime = reminderEnabled ? reminderTime : nil

        let toDo: ToDo
        if let existingToDo = toDoToEdit {
            toDo = existingToDo
            toDo.title = trimmedTitle
            toDo.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            toDo.scheduledDate = Calendar.current.startOfDay(for: scheduledDate)
        } else {
            toDo = ToDo(
                title: trimmedTitle,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                scheduledDate: Calendar.current.startOfDay(for: scheduledDate)
            )
            modelContext.insert(toDo)
        }
        toDo.reminderTime = newReminderTime
        toDo.startTime = timeEnabled ? startTime : nil
        toDo.endTime = (timeEnabled && endTimeEnabled) ? endTime : nil

        if newReminderTime != nil {
            NotificationService.scheduleReminder(for: toDo)
        } else {
            NotificationService.cancelReminder(for: toDo)
        }

        try? modelContext.save()
        dismiss()
    }
}
