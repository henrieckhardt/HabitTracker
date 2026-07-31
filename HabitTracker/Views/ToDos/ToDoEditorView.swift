import SwiftUI
import SwiftData

struct ToDoEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var scheduledDate: Date

    init(defaultDate: Date) {
        _scheduledDate = State(initialValue: defaultDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Titel") {
                    TextField("z.B. Auto zur Inspektion bringen", text: $title)
                }
                Section("Notizen") {
                    TextField("Optional", text: $notes, axis: .vertical)
                }
                Section("Fällig am") {
                    DatePicker("Datum", selection: $scheduledDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                }
            }
            .navigationTitle("Neues ToDo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let toDo = ToDo(
            title: title.trimmingCharacters(in: .whitespaces),
            notes: notes.trimmingCharacters(in: .whitespaces).isEmpty ? nil : notes,
            scheduledDate: Calendar.current.startOfDay(for: scheduledDate)
        )
        modelContext.insert(toDo)
        try? modelContext.save()
        dismiss()
    }
}
