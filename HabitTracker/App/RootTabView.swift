import SwiftUI
import SwiftData

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            DayView()
                .tabItem {
                    Label("Heute", systemImage: "calendar")
                }
            HabitListView()
                .tabItem {
                    Label("Habits", systemImage: "checkmark.circle")
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                RolloverService.rolloverIfNeeded(context: modelContext)
            }
        }
    }
}
