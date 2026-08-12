import AppIntents
import SwiftData
import WidgetKit

/// The to-do counterpart to `ToggleHabitIntent` — see its doc comment for
/// why this lives under `HabitTracker/Intents/` and opens its own
/// short-lived `ModelContainer` rather than assuming a shared one.
struct ToggleToDoIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle To-Do"
    static var description = IntentDescription("Marks a to-do complete or incomplete.")

    @Parameter(title: "To-Do ID")
    var toDoID: String

    init() {}

    init(toDoID: UUID) {
        self.toDoID = toDoID.uuidString
    }

    func perform() async throws -> some IntentResult {
        defer { WidgetCenter.shared.reloadAllTimelines() }

        guard let id = UUID(uuidString: toDoID),
              let container = try? ModelContainer(
                for: Habit.self, HabitCompletion.self, ToDo.self, FocusSession.self, FocusRun.self,
                configurations: AppGroup.makeModelConfiguration()
              )
        else { return .result() }

        ItemCompletionService.toggleToDo(id: id, context: ModelContext(container))
        return .result()
    }
}
