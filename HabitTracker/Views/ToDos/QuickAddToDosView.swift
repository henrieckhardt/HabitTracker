import SwiftUI
import SwiftData

/// Notes-app-style bulk entry: one line of free text per ToDo, all scheduled
/// for the same day. Deliberately minimal (no notes/reminder fields here —
/// those stay a job for `ToDoEditorView` when editing afterward), since the
/// point is to get many titles down as fast as possible.
struct QuickAddToDosView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let date: Date

    @State private var text = ""
    @FocusState private var isFocused: Bool

    private var calendar: Calendar { .current }

    private var lines: [String] {
        text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var dayLabel: String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("EEEE, d. MMM")
        return formatter.string(from: date)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .focused($isFocused)
                    .padding(12)

                if text.isEmpty {
                    Text("One to-do per line, e.g.\nGroceries\nDo laundry\nWash the car")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                        .allowsHitTesting(false)
                }
            }
            .navigationTitle(dayLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addAll() }
                        .disabled(lines.isEmpty)
                }
            }
            .onAppear { isFocused = true }
        }
    }

    private func addAll() {
        let scheduledDate = calendar.startOfDay(for: date)
        for (index, title) in lines.enumerated() {
            let toDo = ToDo(
                title: title,
                scheduledDate: scheduledDate,
                createdAt: .now.addingTimeInterval(Double(index) * 0.001)
            )
            modelContext.insert(toDo)
        }
        try? modelContext.save()
        dismiss()
    }
}
