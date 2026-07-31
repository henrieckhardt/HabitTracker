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

    init(toDo: ToDo? = nil, defaultDate: Date = Calendar.current.startOfDay(for: .now)) {
        self.toDoToEdit = toDo
        _title = State(initialValue: toDo?.title ?? "")
        _notes = State(initialValue: toDo?.notes ?? "")
        _scheduledDate = State(initialValue: toDo?.scheduledDate ?? defaultDate)
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
            .navigationTitle(toDoToEdit == nil ? "Neues ToDo" : "ToDo bearbeiten")
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
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)

        if let toDo = toDoToEdit {
            toDo.title = trimmedTitle
            toDo.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            toDo.scheduledDate = Calendar.current.startOfDay(for: scheduledDate)
        } else {
            let toDo = ToDo(
                title: trimmedTitle,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                scheduledDate: Calendar.current.startOfDay(for: scheduledDate)
            )
            modelContext.insert(toDo)
        }
        try? modelContext.save()
        dismiss()
    }
}
