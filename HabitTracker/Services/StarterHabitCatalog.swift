import Foundation

/// Small, curated set of habits offered on the last onboarding page so a
/// fresh install isn't five empty tabs — picking any subset (or none) just
/// inserts ordinary `Habit` objects, fully editable/deletable afterward like
/// anything the user creates themselves.
enum StarterHabitCatalog {
    struct Item: Identifiable, Equatable {
        /// A stable slug, not a `UUID` — keeps this catalog (and its tests)
        /// deterministic across launches instead of re-randomizing identity
        /// every time the app runs.
        let id: String
        let title: String
        let icon: String
        let colorTag: String
        let recurrenceRule: RecurrenceRule
    }

    static let all: [Item] = [
        Item(id: "drink-water", title: String(localized: "Drink Water"), icon: "drop.fill", colorTag: "blue", recurrenceRule: .daily),
        Item(id: "move", title: String(localized: "Move for 20 Minutes"), icon: "figure.walk", colorTag: "green", recurrenceRule: .daily),
        Item(id: "read", title: String(localized: "Read"), icon: "book.fill", colorTag: "orange", recurrenceRule: .daily),
        Item(id: "sleep-early", title: String(localized: "Sleep Before Midnight"), icon: "moon.fill", colorTag: "indigo", recurrenceRule: .daily),
        Item(id: "plan-week", title: String(localized: "Plan the Week"), icon: "calendar", colorTag: "purple", recurrenceRule: .weekdays([.sunday])),
        Item(id: "workout", title: String(localized: "Workout"), icon: "dumbbell.fill", colorTag: "red", recurrenceRule: .weekdays([.monday, .wednesday, .friday])),
        Item(id: "journal", title: String(localized: "Journal"), icon: "pencil.and.outline", colorTag: "brown", recurrenceRule: .daily),
        Item(id: "no-phone-before-bed", title: String(localized: "No Phone Before Bed"), icon: "iphone.slash", colorTag: "gray", recurrenceRule: .daily)
    ]

    /// Assigns strictly increasing `Habit.sortOrder` values that preserve
    /// this catalog's order, so however many starter habits a user picks
    /// interleave predictably in `DayView`'s unified list on first launch —
    /// same numeric space as `Habit.sortOrder`/`ToDo.sortOrder`.
    static func sortOrder(for index: Int, baseline: Date = .now) -> Double {
        baseline.timeIntervalSinceReferenceDate + Double(index) * 0.001
    }
}
