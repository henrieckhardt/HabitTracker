import SwiftUI
import SwiftData

struct FocusEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// nil when creating a new session.
    private let sessionToEdit: FocusSession?

    @State private var title: String
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var recurrenceState: RecurrenceEditorState

    private static var defaultStartTime: Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
    }

    private static var defaultEndTime: Date {
        Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: .now) ?? .now
    }

    init(session: FocusSession? = nil) {
        self.sessionToEdit = session
        _title = State(initialValue: session?.title ?? "")
        _startTime = State(initialValue: session?.startTime ?? Self.defaultStartTime)
        _endTime = State(initialValue: session?.endTime ?? Self.defaultEndTime)
        _recurrenceState = State(initialValue: RecurrenceEditorState.from(session?.recurrenceRule ?? .daily))
    }

    /// Only the hour/minute of `startTime`/`endTime` matter; MVP doesn't
    /// support windows that span midnight.
    private var isTimeRangeValid: Bool {
        let calendar = Calendar.current
        let startMinutes = calendar.component(.hour, from: startTime) * 60 + calendar.component(.minute, from: startTime)
        let endMinutes = calendar.component(.hour, from: endTime) * 60 + calendar.component(.minute, from: endTime)
        return endMinutes > startMinutes
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("z.B. Deep Work", text: $title)
                }

                Section("Zeitraum") {
                    DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("Ende", selection: $endTime, displayedComponents: .hourAndMinute)
                    if !isTimeRangeValid {
                        Text("Die Endzeit muss nach der Startzeit liegen.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section("Wiederholung") {
                    RecurrencePickerView(state: $recurrenceState)
                }
            }
            .navigationTitle(sessionToEdit == nil ? "Neuer Fokus" : "Fokus bearbeiten")
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
                                || !isTimeRangeValid
                        )
                }
            }
        }
    }

    private func save() {
        let rule = recurrenceState.buildRule()
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)

        if let session = sessionToEdit {
            session.title = trimmedTitle
            session.startTime = startTime
            session.endTime = endTime
            session.recurrenceRule = rule
        } else {
            let session = FocusSession(title: trimmedTitle, startTime: startTime, endTime: endTime, recurrenceRule: rule)
            modelContext.insert(session)
        }
        try? modelContext.save()
        dismiss()
    }
}
