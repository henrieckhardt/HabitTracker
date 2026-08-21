import SwiftUI

/// The habit-specific counterpart to `ShareCardPreviewSheet` — swipe
/// between two distinct cards (current streak, all-time totals) instead of
/// previewing a single one. Kept separate rather than generalizing
/// `ShareCardPreviewSheet`'s `CardContent` type parameter to a page index,
/// since it's the only share flow with more than one card type.
///
/// Uses a hand-built `ScrollView` carousel instead of `TabView(.page)`:
/// `TabView` always sizes each page to fill its container exactly, so
/// there's no way to let the neighboring card peek in at the edges the way
/// Strava's card picker does.
struct HabitShareCardsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let habit: Habit
    let currentStreak: Int
    let longestStreak: Int
    let totalCompletions: Int
    let allTimeCompletionRate: Double
    let historyGrid: [[HabitHistoryEngine.DayCell]]

    @State private var page: Int? = 0
    @State private var exportData: Data?

    private var currentPage: Int { page ?? 0 }
    private var fileName: String { currentPage == 0 ? "habiz-streak" : "habiz-alltime" }

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                carousel
                pageDots
                Spacer()
                if let exportData, let preview = UIImage(data: exportData) {
                    ShareLink(item: ShareCardPNG(data: exportData), preview: SharePreview(fileName, image: Image(uiImage: preview))) {
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
            .task(id: currentPage) {
                exportData = currentPage == 0
                    ? ShareCardRenderer.renderPNG {
                        HabitStreakShareCard(habit: habit, currentStreak: currentStreak, longestStreak: longestStreak, historyGrid: historyGrid)
                    }
                    : ShareCardRenderer.renderPNG {
                        HabitAllTimeShareCard(habit: habit, totalCompletions: totalCompletions, allTimeCompletionRate: allTimeCompletionRate)
                    }
            }
        }
    }

    /// Scaled down from the card's real export size so there's slack left
    /// in the viewport for both a leading margin and a visible peek of the
    /// next card — at the full 360×450 export size there's barely 40pt of
    /// slack on a typical phone width, nowhere near enough for either.
    private let previewScale: CGFloat = 0.82
    private let previewInset: CGFloat = 24
    private let previewSpacing: CGFloat = 16

    private var carousel: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: previewSpacing) {
                cardPreview {
                    HabitStreakShareCard(habit: habit, currentStreak: currentStreak, longestStreak: longestStreak, historyGrid: historyGrid)
                }
                .id(0)

                cardPreview {
                    HabitAllTimeShareCard(habit: habit, totalCompletions: totalCompletions, allTimeCompletionRate: allTimeCompletionRate)
                }
                .id(1)
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $page)
        .scrollIndicators(.hidden)
        .safeAreaPadding(.horizontal, previewInset)
        .frame(height: ShareCardRenderer.cardPointSize.height * previewScale)
    }

    /// Wraps a card with the checkerboard that stands in for its real
    /// transparent background, purely so the white-on-white card content
    /// doesn't disappear against the sheet while previewing — the actual
    /// export (built separately in `.task`) never gets this background or
    /// this scale-down.
    private func cardPreview<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .scaleEffect(previewScale)
            .frame(width: ShareCardRenderer.cardPointSize.width * previewScale, height: ShareCardRenderer.cardPointSize.height * previewScale)
            .background(TransparencyCheckerboard())
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<2) { index in
                Circle()
                    .fill(index == currentPage ? Color.primary : Color.primary.opacity(0.25))
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.top, 12)
    }
}

/// Stand-in for a transparent PNG's checkered "no background" look — the
/// same visual convention Strava, Files, and image editors use so a
/// transparent preview doesn't just read as a blank card.
private struct TransparencyCheckerboard: View {
    var tile: CGFloat = 16

    var body: some View {
        Canvas { context, size in
            let columns = Int(ceil(size.width / tile))
            let rows = Int(ceil(size.height / tile))
            for row in 0..<rows {
                for column in 0..<columns where (row + column).isMultiple(of: 2) {
                    let rect = CGRect(x: CGFloat(column) * tile, y: CGFloat(row) * tile, width: tile, height: tile)
                    context.fill(Path(rect), with: .color(Color(white: 0.3)))
                }
            }
        }
        .background(Color(white: 0.42))
    }
}
