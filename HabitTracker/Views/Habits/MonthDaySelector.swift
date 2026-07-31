import SwiftUI

/// Grid of day-of-month toggle buttons (1–31) for the "individuell" monthly preset.
struct MonthDaySelector: View {
    @Binding var selection: Set<Int>

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(1...31, id: \.self) { day in
                let isSelected = selection.contains(day)
                Button {
                    if isSelected {
                        selection.remove(day)
                    } else {
                        selection.insert(day)
                    }
                } label: {
                    Text("\(day)")
                        .font(.footnote.weight(.medium))
                        .frame(width: 32, height: 32)
                        .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
