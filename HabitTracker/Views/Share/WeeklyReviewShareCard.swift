import SwiftUI

/// "Here's my week" — the same three numbers as `WeeklySummaryCard` on
/// `ProfileView`, re-themed for a dark exportable card instead of an
/// in-app tile row.
struct WeeklyReviewShareCard: View {
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
        ShareCardFrame {
            VStack(spacing: 28) {
                Text("This Week")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(.white)

                VStack(spacing: 18) {
                    row(value: "\(Int((weekCompletionRate * 100).rounded()))%", label: "Habits Completed", icon: "checkmark.circle.fill")
                    row(value: "\(toDoStats.completed)/\(toDoStats.total)", label: "To-Dos Done", icon: "checklist")
                    row(value: focusMinutesText, label: "Focused", icon: "timer")
                }

                if bestCurrentStreak > 0 {
                    Label("\(bestCurrentStreak) day streak", systemImage: "flame.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private func row(value: String, label: LocalizedStringKey, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.15))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer(minLength: 0)
        }
        .frame(width: 220)
    }
}
