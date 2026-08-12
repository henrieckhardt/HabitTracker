import DeviceActivity
import FamilyControls
import ManagedSettings
import SwiftData
import Foundation
import os

/// Fires when a scheduled Focus window (see `FocusBlockingScheduler`)
/// starts/ends. `DeviceActivitySchedule` only knows daily start/end times,
/// so this checks `RecurrenceEngine.isScheduled` itself before applying the
/// shield — that's how a weekdays-only or monthly Focus session skips days
/// it isn't due on.
final class FocusShieldMonitorExtension: DeviceActivityMonitor {
    /// `os.Logger` instead of `print` — this process is launched by the
    /// system, not by Xcode, so stdout usually isn't attached to anything
    /// during a real (non-debugger-attached) firing. Unified logging is
    /// always captured and visible in Console.app (search the device for
    /// the FocusShieldMonitor process) regardless of whether Xcode is
    /// attached, which is the only reliable way to confirm whether this
    /// extension is actually being invoked by the system at all.
    private let logger = Logger(subsystem: "com.henrieckhardt.habittracker.FocusShieldMonitor", category: "shield")

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        logger.notice("intervalDidStart fired for \(activity.rawValue, privacy: .public)")
        applyShieldIfScheduledToday(for: activity)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        logger.notice("intervalDidEnd fired for \(activity.rawValue, privacy: .public)")
        removeShield(for: activity)
    }

    private func applyShieldIfScheduledToday(for activity: DeviceActivityName) {
        guard let session = fetchSession(id: activity.rawValue) else {
            logger.error("applyShieldIfScheduledToday: no FocusSession found for \(activity.rawValue, privacy: .public)")
            return
        }
        // On-demand sessions have no recurrence — they were started manually
        // right now, so there's no "is today a scheduled day" check to make.
        guard session.isOnDemand || RecurrenceEngine.isScheduled(session.recurrenceRule, on: .now) else {
            logger.notice("Not applying shield for '\(session.title, privacy: .public)' — not scheduled today")
            return
        }
        guard let selection = session.blockedSelection else {
            logger.error("Not applying shield for '\(session.title, privacy: .public)' — no blockedSelection stored")
            return
        }

        let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(activity.rawValue))
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        logger.notice("Applied shield for '\(session.title, privacy: .public)': \(selection.applicationTokens.count) apps, \(selection.categoryTokens.count) categories")
    }

    private func removeShield(for activity: DeviceActivityName) {
        let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(activity.rawValue))
        store.shield.applications = nil
        store.shield.applicationCategories = nil
    }

    private func fetchSession(id: String) -> FocusSession? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        guard let container = try? ModelContainer(
            for: Habit.self, HabitCompletion.self, ToDo.self, FocusSession.self, FocusRun.self,
            configurations: AppGroup.makeModelConfiguration()
        ) else {
            logger.error("fetchSession: failed to open shared ModelContainer")
            return nil
        }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<FocusSession>(predicate: #Predicate { $0.id == uuid })
        return try? context.fetch(descriptor).first
    }
}
