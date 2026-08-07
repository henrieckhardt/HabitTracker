import SwiftUI
import SwiftData

struct StatsView: View {
    @Query(filter: #Predicate<Habit> { !$0.isArchived }, sort: \Habit.createdAt)
    private var habits: [Habit]

    var body: some View {
        NavigationStack {
            Group {
                if habits.isEmpty {
                    ContentUnavailableView(
                        "Keine Habits",
                        systemImage: "chart.bar",
                        description: Text("Lege Habits an, um Statistiken zu sehen.")
                    )
                } else {
                    List(habits) { habit in
                        HabitStatsRow(habit: habit)
                    }
                }
            }
            .navigationTitle("Statistik")
        }
    }
}

private struct HabitStatsRow: View {
    let habit: Habit

    private var currentStreak: Int { StreakEngine.currentStreak(for: habit) }
    private var longestStreak: Int { StreakEngine.longestStreak(for: habit) }
    private var completionRate: Double { StreakEngine.completionRate(for: habit) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: habit.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Circle())
                Text(habit.title)
                    .font(.headline)
                Spacer()
            }
            HStack(spacing: 0) {
                StatTile(value: "\(currentStreak)", label: "Aktuell", systemImage: "flame.fill", tint: .orange)
                StatTile(value: "\(longestStreak)", label: "Bester", systemImage: "trophy.fill", tint: .yellow)
                StatTile(value: "\(Int((completionRate * 100).rounded()))%", label: "30 Tage", systemImage: "chart.bar.fill", tint: .accentColor)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct StatTile: View {
    let value: String
    let label: LocalizedStringKey
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            Label(value, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
