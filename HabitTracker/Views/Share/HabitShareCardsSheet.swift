import SwiftUI

/// The habit-specific counterpart to `ShareCardPreviewSheet` — swipe
/// between two distinct cards (current streak, all-time totals) instead of
/// previewing a single one. Kept separate rather than generalizing
/// `ShareCardPreviewSheet`'s `CardContent` type parameter to a page index,
/// since it's the only share flow with more than one card type.
struct HabitShareCardsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let habit: Habit
    let currentStreak: Int
    let longestStreak: Int
    let totalCompletions: Int
    let allTimeCompletionRate: Double
    let historyGrid: [[HabitHistoryEngine.DayCell]]

    @State private var page = 0
    @State private var exportURL: URL?

    private var fileName: String {
        page == 0 ? "habiz-streak" : "habiz-alltime"
    }

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                TabView(selection: $page) {
                    HabitStreakShareCard(
                        habit: habit,
                        currentStreak: currentStreak,
                        longestStreak: longestStreak,
                        historyGrid: historyGrid
                    )
                    .tag(0)

                    HabitAllTimeShareCard(
                        habit: habit,
                        totalCompletions: totalCompletions,
                        allTimeCompletionRate: allTimeCompletionRate
                    )
                    .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .frame(height: ShareCardRenderer.cardPointSize.height + 40)
                Spacer()
                if let exportURL, let preview = UIImage(contentsOfFile: exportURL.path) {
                    ShareLink(item: exportURL, preview: SharePreview(fileName, image: Image(uiImage: preview))) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding()
                } else {
                    ProgressView()
                        .padding()
                }
            }
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task(id: page) {
                exportURL = page == 0
                    ? ShareCardRenderer.writeTemporaryPNG(named: fileName) {
                        HabitStreakShareCard(habit: habit, currentStreak: currentStreak, longestStreak: longestStreak, historyGrid: historyGrid)
                    }
                    : ShareCardRenderer.writeTemporaryPNG(named: fileName) {
                        HabitAllTimeShareCard(habit: habit, totalCompletions: totalCompletions, allTimeCompletionRate: allTimeCompletionRate)
                    }
            }
        }
    }
}
