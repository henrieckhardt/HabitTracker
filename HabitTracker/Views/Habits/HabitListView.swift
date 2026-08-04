import SwiftUI
import SwiftData

struct HabitListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Habit> { !$0.isArchived },
        sort: \Habit.createdAt
    )
    private var habits: [Habit]

    @State private var showingAddHabit = false
    @State private var habitToEdit: Habit?

    var body: some View {
        NavigationStack {
            Group {
                if habits.isEmpty {
                    ContentUnavailableView(
                        "Keine Habits",
                        systemImage: "checkmark.circle",
                        description: Text("Lege deinen ersten Habit an.")
                    )
                } else {
                    List {
                        ForEach(habits) { habit in
                            Button {
                                habitToEdit = habit
                            } label: {
                                HabitRow(habit: habit)
                            }
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button("Archivieren", systemImage: "archivebox") {
                                    habit.isArchived = true
                                    NotificationService.cancelReminders(for: habit)
                                    if let session = habit.focusSession {
                                        session.isArchived = true
                                        FocusBlockingScheduler.stop(session)
                                    }
                                    try? modelContext.save()
                                }
                                .tint(.orange)

                                Button("Löschen", systemImage: "trash", role: .destructive) {
                                    NotificationService.cancelReminders(for: habit)
                                    if let session = habit.focusSession {
                                        FocusBlockingScheduler.stop(session)
                                    }
                                    modelContext.delete(habit)
                                    try? modelContext.save()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Habits")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddHabit = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddHabit) {
                HabitEditorView()
            }
            .sheet(item: $habitToEdit) { habit in
                HabitEditorView(habit: habit)
            }
        }
    }
}

private struct HabitRow: View {
    let habit: Habit

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: habit.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 36, height: 36)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.title)
                    .foregroundStyle(.primary)
                Text(habit.recurrenceRule.summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }
}
