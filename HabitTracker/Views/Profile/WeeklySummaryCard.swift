import SwiftUI

/// The habits/to-dos/focus-time roundup at the top of `ProfileView`. Pure
/// presentation — all the actual numbers come from `AggregateStatsEngine`
/// and `FocusStatsEngine`, computed by the caller and passed in.
struct WeeklySummaryCard: View {
    let weekCompletionRate: Double
    let toDoStats: AggregateStatsEngine.ToDoStats
    let focusMinutesThisWeek: Int
    let bestCurrentStreak: Int

    private var focusMinutesText: String {
        let hours = focusMinutesThisWeek / 60
        let minutes = focusMinutesThisWeek % 60
        switch (hours, minutes) {
        case (0, _): return String(localized: "\(minutes)m")
        case (_, 0): return String(localized: "\(hours)h")
        default: return String(localized: "\(hours)h \(minutes)m")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This Week")
                .font(.headline)

            HStack(spacing: 0) {
                StatTile(
                    value: "\(Int((weekCompletionRate * 100).rounded()))%",
                    label: "Habits",
                    systemImage: "checkmark.circle.fill",
                    tint: .accentColor
                )
                StatTile(
                    value: "\(toDoStats.completed)/\(toDoStats.total)",
                    label: "To-Dos",
                    systemImage: "checklist",
                    tint: .blue
                )
                StatTile(
                    value: focusMinutesText,
                    label: "Focus",
                    systemImage: "timer",
                    tint: .indigo
                )
            }

            if bestCurrentStreak > 0 {
                Label("Best current streak: \(bestCurrentStreak) days", systemImage: "flame.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
