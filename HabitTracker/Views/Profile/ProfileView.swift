import SwiftUI
import SwiftData

/// Replaces the old Statistik tab: instead of a flat, non-tappable list of
/// the same habits `HabitListView` already shows, Profile is the one place
/// aggregating *across* habits/to-dos/focus — the per-habit breakdown lives
/// on `HabitDetailView`, reached from the Habits tab, where it belongs next
/// to editing/archiving that habit.
struct ProfileView: View {
    @Query(filter: #Predicate<Habit> { !$0.isArchived }, sort: \Habit.createdAt)
    private var habits: [Habit]
    @Query(sort: \ToDo.createdAt) private var allToDos: [ToDo]
    @Query private var allFocusRuns: [FocusRun]

    @State private var showingSettings = false

    private var calendar: Calendar {
        CalendarProvider.current
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    WeeklySummaryCard(
                        weekCompletionRate: AggregateStatsEngine.weekCompletionRate(habits: habits, containing: .now, calendar: calendar),
                        toDoStats: AggregateStatsEngine.toDoStats(toDos: allToDos, on: .now, calendar: calendar),
                        focusMinutesThisWeek: FocusStatsEngine.weekMinutes(allFocusRuns, containing: .now, calendar: calendar),
                        bestCurrentStreak: AggregateStatsEngine.bestCurrentStreak(habits: habits, today: .now, calendar: calendar)
                    )
                }
                .padding()
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
}
