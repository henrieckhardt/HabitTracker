import SwiftUI

/// "I've kept this habit going" — the headline number is the current
/// streak; the grid underneath is the same shape as `HabitHistoryGridView`
/// but re-themed for a dark card and drawn at a fixed size rather than
/// `HabitHistoryGridView`'s screen-scrollable one, since this is exported
/// as a single flat image.
struct HabitStreakShareCard: View {
    let habit: Habit
    let currentStreak: Int
    let longestStreak: Int
    let historyGrid: [[HabitHistoryEngine.DayCell]]

    var body: some View {
        ShareCardFrame {
            VStack(spacing: 22) {
                Image(systemName: habit.icon)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 84, height: 84)
                    .background(.white.opacity(0.15))
                    .clipShape(Circle())

                Text(habit.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                VStack(spacing: 2) {
                    Text("\(currentStreak)")
                        .font(.system(size: 68, weight: .heavy))
                        .foregroundStyle(.white)
                    Text("Day Streak")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .textCase(.uppercase)
                        .tracking(1)
                }

                historyGridView

                if longestStreak > currentStreak {
                    Text("Best streak: \(longestStreak) days")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }

    private var historyGridView: some View {
        HStack(spacing: 3) {
            ForEach(historyGrid, id: \.self) { week in
                VStack(spacing: 3) {
                    ForEach(week, id: \.date) { cell in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(color(for: cell.state))
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
    }

    private func color(for state: HabitHistoryEngine.DayState) -> Color {
        switch state {
        case .completed: .white
        case .missed: .white.opacity(0.14)
        case .notScheduled: .white.opacity(0.07)
        case .beforeCreation: .clear
        case .future: .white.opacity(0.04)
        }
    }
}
