import SwiftUI
import SwiftData

/// Reached by tapping a habit in `HabitListView` — replaces the old
/// tap-to-edit `Button` there. Streaks/completion-rate/history live here
/// instead of the removed `StatsView`, right next to the habit they're
/// about, with editing and archiving/deleting one toolbar tap away instead
/// of a separate screen entirely.
struct HabitDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let habit: Habit

    @Query private var allFocusRuns: [FocusRun]

    @State private var showingEditor = false
    @State private var showingDeleteConfirmation = false
    @State private var showingShareSheet = false

    private var currentStreak: Int { StreakEngine.currentStreak(for: habit) }
    private var longestStreak: Int { StreakEngine.longestStreak(for: habit) }
    private var completionRate: Double { StreakEngine.completionRate(for: habit) }
    private var totalCompletions: Int { StreakEngine.totalCompletions(for: habit) }
    private var allTimeCompletionRate: Double { StreakEngine.allTimeCompletionRate(for: habit) }
    private var focusMinutes: Int { FocusStatsEngine.minutes(allFocusRuns, forHabit: habit.id) }

    private var focusTimeText: String {
        let hours = focusMinutes / 60
        let minutes = focusMinutes % 60
        switch (hours, minutes) {
        case (0, _): return String(localized: "\(minutes) min focused")
        case (_, 0): return String(localized: "\(hours) hr focused")
        default: return String(localized: "\(hours) hr \(minutes) min focused")
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                HStack(spacing: 0) {
                    StatTile(value: "\(currentStreak)", label: "Current", systemImage: "flame.fill", tint: .orange)
                    StatTile(value: "\(longestStreak)", label: "Best", systemImage: "trophy.fill", tint: .yellow)
                    StatTile(value: "\(Int((completionRate * 100).rounded()))%", label: "30 Days", systemImage: "chart.bar.fill", tint: .accentColor)
                }

                HStack(spacing: 0) {
                    StatTile(value: "\(totalCompletions)", label: "Total", systemImage: "checkmark.seal.fill", tint: .green)
                    StatTile(value: "\(Int((allTimeCompletionRate * 100).rounded()))%", label: "All Time", systemImage: "chart.line.uptrend.xyaxis", tint: .accentColor)
                }

                if focusMinutes > 0 {
                    Label(focusTimeText, systemImage: "timer")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("History")
                        .font(.headline)
                    HabitHistoryGridView(habit: habit)
                }

                Spacer(minLength: 24)

                footer
            }
            .padding()
        }
        .navigationTitle(habit.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEditor = true
                } label: {
                    Image(systemName: "pencil")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            HabitEditorView(habit: habit)
        }
        .sheet(isPresented: $showingShareSheet) {
            HabitShareCardsSheet(
                habit: habit,
                currentStreak: currentStreak,
                longestStreak: longestStreak,
                totalCompletions: totalCompletions,
                allTimeCompletionRate: allTimeCompletionRate,
                historyGrid: HabitHistoryEngine.grid(for: habit, weeks: 12, endingOn: .now, calendar: CalendarProvider.current)
            )
        }
        .confirmationDialog("Delete Habit", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                delete()
            }
        } message: {
            Text("This can't be undone.")
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: habit.icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 56, height: 56)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.recurrenceRule.summaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let session = habit.focusSession {
                    Text("\(timeText(session.startTime))–\(timeText(session.endTime))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 12) {
            Button {
                archive()
            } label: {
                Label("Archive", systemImage: "archivebox")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.orange)

            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // Exact same sequence as HabitListView's swipe actions — stops the
    // companion focus session and cancels reminders before the mutation,
    // so nothing orphaned lingers (a stuck shield, a reminder that still
    // fires for an archived/deleted habit).

    private func archive() {
        habit.isArchived = true
        NotificationService.cancelReminders(for: habit)
        if let session = habit.focusSession {
            session.isArchived = true
            FocusBlockingScheduler.stop(session)
        }
        try? modelContext.save()
        dismiss()
    }

    private func delete() {
        NotificationService.cancelReminders(for: habit)
        if let session = habit.focusSession {
            FocusBlockingScheduler.stop(session)
        }
        modelContext.delete(habit)
        try? modelContext.save()
        dismiss()
    }
}
