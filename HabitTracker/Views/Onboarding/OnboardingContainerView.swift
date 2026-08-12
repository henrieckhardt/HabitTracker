import SwiftUI
import SwiftData

/// Shown `.fullScreenCover`'d over `RootTabView` on first launch, gated on
/// `AppSettings.hasCompletedOnboarding`. Four pages: the app's backbone in
/// one sentence, Focus explained, permission priming, starter habits — see
/// the coherence plan's A7 section for why each exists.
struct OnboardingContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var currentPage = 0
    @State private var selectedStarterHabitIDs: Set<String> = []

    private let totalPages = 4

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                OnboardingPageView(
                    systemImage: "checkmark.circle.badge.questionmark",
                    title: "Plan, Focus, Track",
                    message: "Habiz helps you plan your week, protect time for what matters with Focus, and see the habits you're actually keeping."
                )
                .tag(0)

                OnboardingPageView(
                    systemImage: "timer",
                    title: "Focus Blocks Distractions",
                    message: "Start a Focus session and Habiz can block distracting apps until it ends — a real boundary, not just a timer."
                )
                .tag(1)

                PermissionPrimingView()
                    .tag(2)

                StarterHabitsView(selectedIDs: $selectedStarterHabitIDs)
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        currentPage -= 1
                    }
                } else {
                    Spacer().frame(width: 44)
                }
                Spacer()
                Button(currentPage == totalPages - 1 ? String(localized: "Get Started") : String(localized: "Next")) {
                    if currentPage == totalPages - 1 {
                        finish()
                    } else {
                        currentPage += 1
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .interactiveDismissDisabled()
    }

    private func finish() {
        for (index, item) in StarterHabitCatalog.all.enumerated() where selectedStarterHabitIDs.contains(item.id) {
            let habit = Habit(
                title: item.title,
                icon: item.icon,
                colorTag: item.colorTag,
                recurrenceRule: item.recurrenceRule,
                sortOrder: StarterHabitCatalog.sortOrder(for: index)
            )
            modelContext.insert(habit)
        }
        try? modelContext.save()

        AppSettings.hasCompletedOnboarding = true
        AppSettings.onboardingVersion = AppSettings.currentOnboardingVersion
        dismiss()
    }
}
