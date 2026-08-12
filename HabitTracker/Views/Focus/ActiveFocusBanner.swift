import SwiftUI

/// Persistent "a focus is running" banner — shared by `FocusListView` and
/// `DayContentView` (both attach it as `.safeAreaInset(edge: .top)`,
/// **never** a conditional `List` `Section`; see `FocusListView`'s comment
/// on why a conditionally-appearing Section broke sibling-row hit testing).
/// Extracted out of `FocusListView`, where this used to be a private
/// struct, so both hosts share one implementation instead of drifting.
struct ActiveFocusBanner: View {
    @Environment(\.modelContext) private var modelContext
    let session: FocusSession

    private var endDate: Date? {
        session.isOnDemand ? session.activeUntil : session.endTime
    }

    /// `activeLabel` — set when this session was started *for* a specific
    /// to-do/habit (see `DayContentView`'s leading swipe action) — takes
    /// priority over the session's own template title, matching the shield
    /// subtitle in `FocusShieldConfigurationExtension`.
    private var displayTitle: String {
        session.activeLabel ?? session.title
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "timer")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("Currently active: \(displayTitle)")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if let endDate {
                    // System-driven countdown — stays correct on its own,
                    // unlike the plain formatted-string version this
                    // replaced, which needed a 30s `Timer.publish` tick to
                    // avoid showing stale remaining time.
                    Text(timerInterval: Date.now...max(Date.now, endDate), countsDown: true)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            Spacer()
            Button {
                FocusSessionController.stop(session, context: modelContext)
            } label: {
                Image(systemName: "stop.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.red)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }
}
