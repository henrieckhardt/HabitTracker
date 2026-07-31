import SwiftUI

/// Row of day-of-week toggle buttons. When `allowsMultiple` is false, tapping
/// a day replaces the selection instead of adding to it (used for the
/// "wöchentlich" preset, which is always exactly one day).
struct WeekdaySelector: View {
    @Binding var selection: Set<Weekday>
    var allowsMultiple: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Weekday.orderedForDisplay) { day in
                let isSelected = selection.contains(day)
                Button {
                    toggle(day)
                } label: {
                    Text(day.shortLabel)
                        .font(.subheadline.weight(.medium))
                        .frame(width: 36, height: 36)
                        .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggle(_ day: Weekday) {
        if allowsMultiple {
            if selection.contains(day) {
                selection.remove(day)
            } else {
                selection.insert(day)
            }
        } else {
            selection = [day]
        }
    }
}
