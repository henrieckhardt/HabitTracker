import SwiftUI

/// "I've kept this up, ever" — the lifetime counterpart to
/// `HabitStreakShareCard`'s current-streak headline: total check-ins and
/// the completion rate since the habit was created, not just a trailing
/// window. Shown as the second page of `HabitShareCardsSheet`.
struct HabitAllTimeShareCard: View {
    let habit: Habit
    let totalCompletions: Int
    let allTimeCompletionRate: Double

    var body: some View {
        ShareCardFrame(isTransparent: true) {
            VStack(spacing: 28) {
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

                HStack(spacing: 32) {
                    stat(value: "\(totalCompletions)", label: "Total Check-ins")
                    stat(value: "\(Int((allTimeCompletionRate * 100).rounded()))%", label: "All Time")
                }
            }
        }
    }

    private func stat(value: String, label: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 44, weight: .heavy))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
                .textCase(.uppercase)
                .tracking(1)
                .multilineTextAlignment(.center)
        }
    }
}
