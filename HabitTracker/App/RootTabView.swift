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
                    Label("Heute", systemImage: "calendar")
                }
            WeekView()
                .tabItem {
                    Label("Woche", systemImage: "calendar.day.timeline.left")
                }
            HabitListView()
                .tabItem {
                    Label("Habits", systemImage: "checkmark.circle")
                }
            FocusListView()
                .tabItem {
                    Label("Fokus", systemImage: "timer")
                }
            StatsView()
                .tabItem {
                    Label("Statistik", systemImage: "chart.bar.fill")
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                RolloverService.rolloverIfNeeded(context: modelContext)
            }
            // Widget has no way to observe SwiftData changes itself, so
            // nudge it on every phase change — cheap, and covers both
            // "user just checked something off, then left the app" and
            // "user just came back, rollover may have moved things".
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
