import SwiftUI

/// Compact icon+value+label tile. Three side by side form the streak/
/// completion-rate summary on `HabitDetailView` and the weekly summary on
/// `ProfileView` — previously a `private` type duplicated only inside the
/// now-removed `StatsView`.
struct StatTile: View {
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
