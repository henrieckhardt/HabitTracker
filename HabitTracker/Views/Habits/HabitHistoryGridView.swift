import SwiftUI

/// GitHub-contribution-style 12-week grid of a habit's completion history.
/// Read-only in Phase A — cells aren't tappable; retroactively marking a
/// past day complete is a separate feature with its own streak-
/// recomputation questions.
struct HabitHistoryGridView: View {
    let habit: Habit
    var weeks: Int = 12

    private var calendar: Calendar {
        CalendarProvider.current
    }

    private var grid: [[HabitHistoryEngine.DayCell]] {
        HabitHistoryEngine.grid(for: habit, weeks: weeks, endingOn: .now, calendar: calendar)
    }

    private let cellSize: CGFloat = 11
    private let cellSpacing: CGFloat = 3

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: cellSpacing) {
                ForEach(grid, id: \.self) { week in
                    VStack(spacing: cellSpacing) {
                        ForEach(week, id: \.date) { cell in
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(color(for: cell.state))
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func color(for state: HabitHistoryEngine.DayState) -> Color {
        switch state {
        case .completed: Color.accentColor
        case .missed: Color.red.opacity(0.3)
        case .notScheduled: Color.secondary.opacity(0.12)
        case .beforeCreation: Color.clear
        case .future: Color.secondary.opacity(0.06)
        }
    }
}
