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

    var body: some View {
        NavigationStack {
            Group {
                if habits.isEmpty {
                    ContentUnavailableView(
                        "No Habits",
                        systemImage: "checkmark.circle",
                        description: Text("Create your first habit.", comment: "Empty state description on the Habits list")
                    )
                } else {
                    List {
                        ForEach(habits) { habit in
                            NavigationLink {
                                HabitDetailView(habit: habit)
                            } label: {
                                HabitRow(habit: habit)
                            }
                            .swipeActions {
                                Button("Archive", systemImage: "archivebox") {
                                    habit.isArchived = true
                                    NotificationService.cancelReminders(for: habit)
                                    if let session = habit.focusSession {
                                        session.isArchived = true
                                        FocusBlockingScheduler.stop(session)
                                    }
                                    try? modelContext.save()
                                }
                                .tint(.orange)

                                Button("Delete", systemImage: "trash", role: .destructive) {
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
        }
    }
}

private struct HabitRow: View {
    let habit: Habit

    private var currentStreak: Int {
        StreakEngine.currentStreak(for: habit)
    }

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
            // Plain Label, deliberately not a Button — nesting a
            // Button-like control inside a NavigationLink's label is the
            // exact hit-testing hazard documented on RecurrencePickerView
            // and FocusListView's ActiveFocusBanner extraction.
            if currentStreak > 0 {
                Label("\(currentStreak)", systemImage: "flame.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
        .contentShape(Rectangle())
    }
}
