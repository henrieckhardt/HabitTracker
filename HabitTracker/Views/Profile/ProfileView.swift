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
    @State private var showingShareSheet = false

    private var calendar: Calendar {
        CalendarProvider.current
    }

    private var weekCompletionRate: Double {
        AggregateStatsEngine.weekCompletionRate(habits: habits, containing: .now, calendar: calendar)
    }
    private var toDoStats: AggregateStatsEngine.ToDoStats {
        AggregateStatsEngine.toDoStats(toDos: allToDos, on: .now, calendar: calendar)
    }
    private var focusMinutesThisWeek: Int {
        FocusStatsEngine.weekMinutes(allFocusRuns, containing: .now, calendar: calendar)
    }
    private var bestCurrentStreak: Int {
        AggregateStatsEngine.bestCurrentStreak(habits: habits, today: .now, calendar: calendar)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    WeeklySummaryCard(
                        weekCompletionRate: weekCompletionRate,
                        toDoStats: toDoStats,
                        focusMinutesThisWeek: focusMinutesThisWeek,
                        bestCurrentStreak: bestCurrentStreak
                    )

                    Button {
                        showingShareSheet = true
                    } label: {
                        Label("Share This Week", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
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
            .sheet(isPresented: $showingShareSheet) {
                ShareCardPreviewSheet(fileName: "habiz-week") {
                    WeeklyReviewShareCard(
                        weekCompletionRate: weekCompletionRate,
                        toDoStats: toDoStats,
                        focusMinutesThisWeek: focusMinutesThisWeek,
                        bestCurrentStreak: bestCurrentStreak
                    )
                }
            }
        }
    }
}
