import Foundation

/// Central `UserDefaults` keys for user-configurable, app-wide state.
///
/// Backed by the App Group suite (`AppGroup.identifier`), not `.standard` —
/// so the widget and the completion `AppIntent`s (see the Focus/Habits
/// coherence plan) read the exact same values as the main app instead of
/// each holding their own copy. `HabitTrackerApp` installs `defaults` as the
/// environment's `.defaultAppStorage`, so `@AppStorage(AppSettings.Key.foo)`
/// anywhere in the view tree already hits this suite without repeating
/// `store:` at every call site.
///
/// `RolloverService`'s `lastRolloverCheckDate` deliberately stays on
/// `.standard` — it's app-process-only bookkeeping, and moving it here would
/// just cost one harmless extra rollover check the first time this ships.
enum AppSettings {
    static let defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard

    enum Key {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let onboardingVersion = "onboardingVersion"
        static let weekStartWeekday = "weekStartWeekday"
        static let defaultReminderMinutes = "defaultReminderMinutes"
        static let defaultFocusDurationMinutes = "defaultFocusDurationMinutes"
        static let promptCompleteAfterFocus = "promptCompleteAfterFocus"
        static let profileName = "profileName"
    }

    enum Default {
        /// Monday — matches `WeekdaySelector`'s ordering and the
        /// `firstWeekday = 2` that `WeekView` used to hardcode.
        static let weekStartWeekday = 2
        /// 09:00 — matches the `bySettingHour: 9` default that
        /// `HabitEditorView`/`ToDoEditorView` used to hardcode.
        static let reminderMinutes = 9 * 60
        static let focusDurationMinutes = 30
        static let promptCompleteAfterFocus = true
    }

    /// 1-indexed like `Calendar.Component.weekday` (1 = Sunday … 7 =
    /// Saturday), so it can be assigned directly to `Calendar.firstWeekday`.
    /// Read via `CalendarProvider.current` rather than this property
    /// directly, outside of Settings UI.
    static var weekStartWeekday: Int {
        get { (defaults.object(forKey: Key.weekStartWeekday) as? Int) ?? Default.weekStartWeekday }
        set { defaults.set(newValue, forKey: Key.weekStartWeekday) }
    }

    /// Minutes since midnight — deliberately not a `Date`: a `Date` stored
    /// in `UserDefaults` is an absolute instant and silently drifts across
    /// timezones, whereas this setting only ever means an hour/minute.
    static var defaultReminderMinutes: Int {
        get { (defaults.object(forKey: Key.defaultReminderMinutes) as? Int) ?? Default.reminderMinutes }
        set { defaults.set(newValue, forKey: Key.defaultReminderMinutes) }
    }

    static var defaultFocusDurationMinutes: Int {
        get { (defaults.object(forKey: Key.defaultFocusDurationMinutes) as? Int) ?? Default.focusDurationMinutes }
        set { defaults.set(newValue, forKey: Key.defaultFocusDurationMinutes) }
    }

    static var promptCompleteAfterFocus: Bool {
        get { (defaults.object(forKey: Key.promptCompleteAfterFocus) as? Bool) ?? Default.promptCompleteAfterFocus }
        set { defaults.set(newValue, forKey: Key.promptCompleteAfterFocus) }
    }
}
