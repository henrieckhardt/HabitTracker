import Foundation
import DeviceActivity
import ManagedSettings

/// Schedules the `FocusShieldMonitor` extension via `DeviceActivityCenter`.
///
/// `DeviceActivitySchedule` only understands a daily start/end time — it has
/// no notion of "only on Tuesdays". So monitoring is always scheduled daily,
/// and `FocusShieldMonitorExtension.intervalDidStart` decides at runtime
/// (via `RecurrenceEngine.isScheduled`) whether today is actually a
/// scheduled day before applying the shield.
///
/// If `intervalEnd` is earlier than `intervalStart`, the framework itself
/// extends the interval into the next day — so an overnight window like
/// 22:00–08:00 needs no special-casing here at all.
///
/// **Important:** `intervalDidStart`/`intervalDidEnd` only fire on a
/// boundary *crossing observed while monitoring is active* — never
/// retroactively. If a session's window already contains "now" at the
/// moment monitoring is (re-)registered (e.g. right after creating/editing
/// a session whose start time has already passed today, or right after
/// tapping "Start" on an on-demand session), the extension will not fire
/// until the *next* crossing — for a daily session, that's tomorrow. So
/// every place that (re)registers monitoring also directly applies/clears
/// the shield on `ManagedSettingsStore` itself, matching whatever the
/// extension would eventually do — `ManagedSettingsStore` works from any
/// process with Family Controls authorization, not just the extension.
enum FocusBlockingScheduler {
    static func activityName(for session: FocusSession) -> DeviceActivityName {
        DeviceActivityName(session.id.uuidString)
    }

    /// Call after every save of a `FocusSession` (create, edit, archive).
    static func reschedule(_ session: FocusSession) {
        let center = DeviceActivityCenter()
        let name = activityName(for: session)
        center.stopMonitoring([name])

        guard session.isBlockingEnabled, !session.isArchived else {
            clearShieldNow(for: session)
            return
        }

        let calendar = Calendar.current
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents([.hour, .minute], from: session.startTime),
            intervalEnd: calendar.dateComponents([.hour, .minute], from: session.endTime),
            repeats: true
        )
        try? center.startMonitoring(name, during: schedule)

        if FocusScheduleEngine.isActive(session, at: .now, calendar: calendar) {
            applyShieldNow(for: session)
        } else {
            clearShieldNow(for: session)
        }
    }

    /// Call when a session is deleted, archived, or its blocking is turned
    /// off. Also clears any shield that's currently applied — stopping
    /// monitoring alone would otherwise leave a shield stuck on forever,
    /// since `intervalDidEnd` can no longer fire once monitoring stops.
    static func stop(_ session: FocusSession) {
        DeviceActivityCenter().stopMonitoring([activityName(for: session)])
        clearShieldNow(for: session)
    }

    /// Starts an on-demand session (`session.isOnDemand == true`) right now
    /// for `session.durationMinutes`. Unlike `reschedule`, this builds a
    /// one-off, non-repeating interval from the current moment — the caller
    /// is responsible for also setting `session.activeUntil` and saving, so
    /// `FocusScheduleEngine.isActive`/the UI agree with what's actually
    /// being monitored.
    static func startNow(_ session: FocusSession) {
        let center = DeviceActivityCenter()
        let name = activityName(for: session)
        center.stopMonitoring([name])

        guard session.isBlockingEnabled else { return }

        let calendar = Calendar.current
        let now = Date.now
        let end = now.addingTimeInterval(TimeInterval(session.durationMinutes * 60))
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents([.hour, .minute, .second], from: now),
            intervalEnd: calendar.dateComponents([.hour, .minute, .second], from: end),
            repeats: false
        )
        try? center.startMonitoring(name, during: schedule)
        // Registering a schedule starting exactly "now" has the same
        // retroactive-firing gap described above — apply immediately
        // instead of waiting on `intervalDidStart`.
        applyShieldNow(for: session)
    }

    /// Ends an on-demand session early. The caller is responsible for
    /// clearing `session.activeUntil` and saving.
    static func stopNow(_ session: FocusSession) {
        stop(session)
    }

    private static func applyShieldNow(for session: FocusSession) {
        guard let selection = session.blockedSelection else { return }
        let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(activityName(for: session).rawValue))
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
    }

    private static func clearShieldNow(for session: FocusSession) {
        let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(activityName(for: session).rawValue))
        store.shield.applications = nil
        store.shield.applicationCategories = nil
    }
}
