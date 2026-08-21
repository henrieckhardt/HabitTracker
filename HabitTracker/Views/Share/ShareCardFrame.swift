import SwiftUI

/// Consistent chrome around every share card's unique content: a fixed
/// dark gradient background and a small "Habiz" wordmark footer, so a
/// habit-streak card, a weekly-review card, and a focus-session card all
/// read as the same product on someone's feed.
///
/// Deliberately pins `.dynamicTypeSize` and `.colorScheme` — this view is
/// rendered off-screen for export (see `ShareCardRenderer`), and every
/// piece of text inside it uses explicit `.system(size:)` fonts rather
/// than semantic styles like `.title`/`.headline`. Without both of those,
/// the exported image would silently vary with whatever accessibility
/// text size or appearance the exporting device happened to be in — the
/// one thing a card that's about to leave the app must never do.
struct ShareCardFrame<Content: View>: View {
    /// `true` for cards meant to be laid over a photo (see
    /// `HabitStreakShareCard`/`HabitAllTimeShareCard`) — no background fill
    /// at all, just the content with a drop shadow for legibility. `false`
    /// keeps the original opaque dark-gradient card used by
    /// `WeeklyReviewShareCard`/`FocusSessionShareCard`.
    var isTransparent: Bool = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            content
            Spacer(minLength: 0)
            footer
        }
        .padding(28)
        .frame(width: ShareCardRenderer.cardPointSize.width, height: ShareCardRenderer.cardPointSize.height)
        .background(background)
        .shadow(color: isTransparent ? .black.opacity(0.35) : .clear, radius: 6, y: 2)
        .environment(\.dynamicTypeSize, .large)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var background: some View {
        if isTransparent {
            Color.clear
        } else {
            LinearGradient(
                colors: [Color(red: 0.11, green: 0.13, blue: 0.22), Color(red: 0.04, green: 0.05, blue: 0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var footer: some View {
        Image("HabizLogo")
            .resizable()
            .scaledToFit()
            .frame(height: 22)
            .opacity(0.6)
            .padding(.top, 20)
    }
}
