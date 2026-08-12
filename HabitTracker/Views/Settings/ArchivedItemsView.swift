import SwiftUI
import SwiftData

/// Archived habits and focus sessions disappear from `HabitListView`/
/// `FocusListView` with no way to bring them back — this is that way back.
/// Reached from `SettingsView`.
struct ArchivedItemsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Habit> { $0.isArchived }, sort: \Habit.createdAt)
    private var archivedHabits: [Habit]

    // Companion sessions (`ownerHabit != nil`) restore implicitly with
    // their habit below — listing them here too would offer two
    // independent ways to unarchive the same underlying window.
    @Query(filter: #Predicate<FocusSession> { $0.isArchived && $0.ownerHabit == nil }, sort: \FocusSession.createdAt)
    private var archivedSessions: [FocusSession]

    var body: some View {
        Group {
            if archivedHabits.isEmpty && archivedSessions.isEmpty {
                ContentUnavailableView(
                    "Nothing Archived",
                    systemImage: "archivebox",
                    description: Text("Archived habits and focus sessions appear here.")
                )
            } else {
                List {
                    if !archivedHabits.isEmpty {
                        Section("Habits") {
                            ForEach(archivedHabits) { habit in
                                row(title: habit.title, icon: habit.icon)
                                    .swipeActions {
                                        Button("Restore", systemImage: "arrow.uturn.backward") {
                                            restore(habit)
                                        }
                                        .tint(.accentColor)
                                        Button("Delete", systemImage: "trash", role: .destructive) {
                                            delete(habit)
                                        }
                                    }
                            }
                        }
                    }
                    if !archivedSessions.isEmpty {
                        Section("Focus Sessions") {
                            ForEach(archivedSessions) { session in
                                row(title: session.title, icon: "timer")
                                    .swipeActions {
                                        Button("Restore", systemImage: "arrow.uturn.backward") {
                                            restore(session)
                                        }
                                        .tint(.accentColor)
                                        Button("Delete", systemImage: "trash", role: .destructive) {
                                            delete(session)
                                        }
                                    }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Archive")
    }

    private func row(title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
    }

    // MARK: - Habits

    private func restore(_ habit: Habit) {
        habit.isArchived = false
        if let session = habit.focusSession {
            session.isArchived = false
            if session.isOnDemand {
                FocusBlockingScheduler.stop(session)
            } else {
                FocusBlockingScheduler.reschedule(session)
            }
        }
        if habit.reminderTime != nil {
            NotificationService.scheduleReminders(for: habit)
        }
        try? modelContext.save()
    }

    // Same sequence as HabitListView's/HabitDetailView's own delete swipe —
    // the companion session (already archived+stopped) is cascade-deleted
    // with the habit, but stopping it again here is cheap and keeps this
    // path correct even if that invariant ever changes.
    private func delete(_ habit: Habit) {
        NotificationService.cancelReminders(for: habit)
        if let session = habit.focusSession {
            FocusBlockingScheduler.stop(session)
        }
        modelContext.delete(habit)
        try? modelContext.save()
    }

    // MARK: - Focus Sessions

    private func restore(_ session: FocusSession) {
        session.isArchived = false
        if session.isOnDemand {
            FocusBlockingScheduler.stop(session)
        } else {
            FocusBlockingScheduler.reschedule(session)
        }
        try? modelContext.save()
    }

    private func delete(_ session: FocusSession) {
        FocusBlockingScheduler.stop(session)
        modelContext.delete(session)
        try? modelContext.save()
    }
}
