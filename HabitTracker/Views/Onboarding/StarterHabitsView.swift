import SwiftUI

/// Last onboarding page: an optional multi-select of `StarterHabitCatalog`
/// items. `OnboardingContainerView` owns the selection and materializes it
/// into real `Habit` objects on "Get Started" — this view only toggles a
/// `Set` of catalog ids, no `ModelContext` here.
///
/// A `ScrollView`, deliberately not a `List` — this page's rows are simple
/// toggleable buttons, and a `ScrollView` avoids `List`'s heavier styling
/// machinery for no benefit here. Rows are plain `Button`s, so none of
/// this codebase's documented List/NavigationLink hit-testing hazards
/// apply to them.
struct StarterHabitsView: View {
    @Binding var selectedIDs: Set<String>

    var body: some View {
        VStack(spacing: 4) {
            Text("Pick a Few Habits to Start")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .padding(.top, 24)
            Text("Optional — you can add, edit, or remove these anytime.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(StarterHabitCatalog.all) { item in
                        let isSelected = selectedIDs.contains(item.id)
                        Button {
                            toggle(item.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.icon)
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 28)
                                Text(item.title)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isSelected ? Color.accentColor : Color(.tertiaryLabel))
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 20)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 20)
                    }
                }
            }
        }
    }

    private func toggle(_ id: String) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }
}
