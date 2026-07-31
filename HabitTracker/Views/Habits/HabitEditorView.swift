import SwiftUI
import SwiftData

struct HabitEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// nil when creating a new habit.
    private let habitToEdit: Habit?

    @State private var title: String
    @State private var icon: String
    @State private var recurrenceState: RecurrenceEditorState

    private static let iconChoices = [
        "checkmark.circle", "flame", "figure.run", "book", "drop",
        "bed.double", "leaf", "cup.and.saucer", "dumbbell", "pills",
        "moon.stars", "sun.max", "heart", "brain.head.profile", "sparkles"
    ]

    init(habit: Habit? = nil) {
        self.habitToEdit = habit
        _title = State(initialValue: habit?.title ?? "")
        _icon = State(initialValue: habit?.icon ?? "checkmark.circle")
        _recurrenceState = State(initialValue: RecurrenceEditorState.from(habit?.recurrenceRule ?? .daily))
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

                RecurrencePickerView(state: $recurrenceState)
            }
            .navigationTitle(habitToEdit == nil ? "Neuer Habit" : "Habit bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || !recurrenceState.isValid)
                }
            }
        }
    }

    private func save() {
        let rule = recurrenceState.buildRule()
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)

        if let habit = habitToEdit {
            habit.title = trimmedTitle
            habit.icon = icon
            habit.recurrenceRule = rule
        } else {
            let habit = Habit(title: trimmedTitle, icon: icon, recurrenceRule: rule)
            modelContext.insert(habit)
        }
        try? modelContext.save()
        dismiss()
    }
}
