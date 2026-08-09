import SwiftUI
import SwiftData
import WidgetKit

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            DayView()
                .tabItem {
                    Label("Today", systemImage: "calendar")
                }
            WeekView()
                .tabItem {
                    Label("Week", systemImage: "calendar.day.timeline.left")
                }
            HabitListView()
                .tabItem {
                    Label("Habits", systemImage: "checkmark.circle")
                }
            FocusListView()
                .tabItem {
                    Label("Focus", systemImage: "timer")
                }
            StatsView()
                .tabItem {
                    Label("Statistics", systemImage: "chart.bar.fill")
                }
        }
        .task {
            DisplayOrderMigration.run(context: modelContext)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                RolloverService.rolloverIfNeeded(context: modelContext)
                // Self-healing safety net: `FocusShieldMonitorExtension`'s
                // `intervalDidStart`/`intervalDidEnd` are known to be
                // unreliable in practice (especially in Xcode-attached
                // Debug builds), so re-sync every Focus session's shield
                // state against the current time whenever the app is
                // opened, instead of relying solely on the extension.
                FocusBlockingScheduler.resyncAll(context: modelContext)
            }
            // Widget has no way to observe SwiftData changes itself, so
            // nudge it on every phase change — cheap, and covers both
            // "user just checked something off, then left the app" and
            // "user just came back, rollover may have moved things".
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
