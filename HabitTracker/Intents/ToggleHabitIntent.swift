import AppIntents
import SwiftData
import WidgetKit

/// Lets the home-screen widget check a habit off without opening the app.
/// Runs in whichever process invokes it (the widget extension when tapped
/// from the home screen) — opens its own short-lived `ModelContainer`
/// against the shared App Group store, same pattern as every other
/// cross-process access to it (see `AppGroup`'s doc comment on why all four
/// processes sharing this store must declare the identical model list).
///
/// Filed under `HabitTracker/Intents/` rather than `Services/`: the app
/// target compiles the whole `HabitTracker` folder automatically, and the
/// widget target picks this up via an explicit `project.yml` source entry
/// — one file, compiled into both processes, since either can end up
/// running it (iOS may execute a widget's intent in the widget extension
/// or hand it to the containing app depending on system state).
struct ToggleHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Habit"
    static var description = IntentDescription("Marks a habit complete or incomplete for today.")

    @Parameter(title: "Habit ID")
    var habitID: String

    init() {}

    init(habitID: UUID) {
        self.habitID = habitID.uuidString
    }

    func perform() async throws -> some IntentResult {
        defer { WidgetCenter.shared.reloadAllTimelines() }

        guard let id = UUID(uuidString: habitID),
              let container = try? ModelContainer(
                for: Habit.self, HabitCompletion.self, ToDo.self, FocusSession.self, FocusRun.self,
                configurations: AppGroup.makeModelConfiguration()
              )
        else { return .result() }

        ItemCompletionService.toggleHabit(id: id, on: .now, context: ModelContext(container))
        return .result()
    }
}
