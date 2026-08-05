import Foundation
import DeviceActivity
import ManagedSettings
import SwiftData

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
    /// `DeviceActivitySchedule` rejects registration with
    /// `DeviceActivityScheduleError.intervalTooShort` if the interval
    /// between start and end is shorter than this — confirmed via a real
    /// `startMonitoring` failure on-device (Apple doesn't expose this as a
    /// public constant). Editors validate against this before saving so the
    /// failure shows up immediately in the UI instead of silently in a
    /// console log.
    static let minimumWindowMinutes = 15

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
        do {
            try center.startMonitoring(name, during: schedule)
        } catch {
            print("⚠️ FocusBlockingScheduler.reschedule: startMonitoring failed for '\(session.title)' (\(name.rawValue)): \(error)")
        }

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
        registerOneOffSchedule(for: session, delayMinutes: 0)
        // Registering a schedule starting exactly "now" has the same
        // retroactive-firing gap described above — apply immediately
        // instead of waiting on `intervalDidStart`.
        applyShieldNow(for: session)
    }

    /// Schedules an on-demand session to begin `delayMinutes` from now
    /// ("Später starten"), for `session.durationMinutes`. Unlike
    /// `startNow`, the shield is deliberately left alone — the window
    /// hasn't begun yet, so nothing should be blocked until
    /// `intervalDidStart` fires (or `resyncAll` catches up once the start
    /// time has passed while the app happens to be foregrounded). The
    /// caller is responsible for setting `session.pendingStart`/
    /// `session.activeUntil` and saving.
    static func scheduleStart(_ session: FocusSession, delayMinutes: Int) {
        registerOneOffSchedule(for: session, delayMinutes: delayMinutes)
    }

    /// Ends an on-demand session early, or cancels a pending future start.
    /// The caller is responsible for clearing `session.activeUntil`/
    /// `session.pendingStart` and saving.
    static func stopNow(_ session: FocusSession) {
        stop(session)
    }

    private static func registerOneOffSchedule(for session: FocusSession, delayMinutes: Int) {
        let center = DeviceActivityCenter()
        let name = activityName(for: session)
        center.stopMonitoring([name])

        guard session.isBlockingEnabled else { return }

        let calendar = Calendar.current
        let start = Date.now.addingTimeInterval(TimeInterval(delayMinutes * 60))
        let end = start.addingTimeInterval(TimeInterval(session.durationMinutes * 60))
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents([.hour, .minute, .second], from: start),
            intervalEnd: calendar.dateComponents([.hour, .minute, .second], from: end),
            repeats: false
        )
        do {
            try center.startMonitoring(name, during: schedule)
        } catch {
            print("⚠️ FocusBlockingScheduler: startMonitoring failed for '\(session.title)' (\(name.rawValue)): \(error)")
        }
    }

    /// Self-healing safety net: call whenever the app becomes active to
    /// re-sync every non-archived session's shield state against the
    /// current time, instead of relying solely on
    /// `FocusShieldMonitorExtension`'s `intervalDidStart`/`intervalDidEnd` —
    /// which are known to be unreliable in practice.
    ///
    /// **Deliberately does NOT call `reschedule`/touch `DeviceActivityCenter`
    /// at all** — only `ManagedSettingsStore` is read/written here. Earlier
    /// this called `reschedule(session)` for every scheduled session on
    /// every foreground, which meant `stopMonitoring`/`startMonitoring` ran
    /// repeatedly (every app open) instead of just once at save time. That's
    /// a real risk: if `deviceactivityd` has an already-armed timer for the
    /// next boundary crossing, tearing down and re-registering monitoring
    /// while that's pending could plausibly cancel it — repeated
    /// re-registration churn is exactly the kind of thing that could turn a
    /// working schedule into one that never fires again. Since this
    /// function only needs to fix up the *shield*, not the *schedule* (that
    /// was already registered once, correctly, when the session was last
    /// saved), it must leave `DeviceActivityCenter` completely alone.
    static func resyncAll(context: ModelContext) {
        // Fetch every session (not just non-archived) so orphan detection
        // below has the full picture of what's legitimately still known.
        guard let allSessions = try? context.fetch(FetchDescriptor<FocusSession>()) else { return }

        cleanUpOrphanedMonitoring(knownSessionIDs: Set(allSessions.map(\.id)))

        for session in allSessions where !session.isArchived && session.isBlockingEnabled {
            if FocusScheduleEngine.isActive(session, at: .now) {
                applyShieldNow(for: session)
            } else if !session.isOnDemand {
                // On-demand sessions that aren't active simply have nothing
                // to do here — they're either not started yet (never had a
                // shield) or already ended (cleared by stopNow or naturally
                // expired); clearing them again is harmless but unnecessary.
                // Scheduled sessions do need the explicit clear so a shield
                // doesn't linger past its window if intervalDidEnd never
                // fired.
                clearShieldNow(for: session)
            }
        }
    }

    /// Stops monitoring for any `DeviceActivityName` iOS currently has
    /// registered that doesn't correspond to a `FocusSession` that still
    /// exists locally — e.g. left over from a session that was deleted
    /// without going through `stop()`, or from the local store being reset
    /// during development (schema/App-Group migrations). iOS tracks
    /// registrations independently of our data, so deleting a session
    /// locally never cleans this up by itself — orphaned registrations can
    /// silently accumulate across many test cycles. Also logs what's
    /// currently registered, visible in Xcode's console, since there's no
    /// other way to see this from inside the app.
    static func cleanUpOrphanedMonitoring(knownSessionIDs: Set<UUID>) {
        let center = DeviceActivityCenter()
        let registered = center.activities
        print("ℹ️ FocusBlockingScheduler: \(registered.count) DeviceActivityName(s) currently registered with iOS: \(registered.map(\.rawValue).sorted())")

        let orphaned = registered.filter { name in
            guard let uuid = UUID(uuidString: name.rawValue) else { return true }
            return !knownSessionIDs.contains(uuid)
        }
        guard !orphaned.isEmpty else { return }
        print("⚠️ FocusBlockingScheduler: stopping \(orphaned.count) orphaned registration(s): \(orphaned.map(\.rawValue))")
        center.stopMonitoring(Array(orphaned))
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
