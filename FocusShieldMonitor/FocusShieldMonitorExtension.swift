import DeviceActivity
import FamilyControls
import ManagedSettings
import SwiftData
import Foundation

/// Fires when a scheduled Focus window (see `FocusBlockingScheduler`)
/// starts/ends. `DeviceActivitySchedule` only knows daily start/end times,
/// so this checks `RecurrenceEngine.isScheduled` itself before applying the
/// shield — that's how a weekdays-only or monthly Focus session skips days
/// it isn't due on.
final class FocusShieldMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        applyShieldIfScheduledToday(for: activity)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        removeShield(for: activity)
    }

    private func applyShieldIfScheduledToday(for activity: DeviceActivityName) {
        guard let session = fetchSession(id: activity.rawValue) else { return }
        // On-demand sessions have no recurrence — they were started manually
        // right now, so there's no "is today a scheduled day" check to make.
        guard session.isOnDemand || RecurrenceEngine.isScheduled(session.recurrenceRule, on: .now) else { return }
        guard let selection = session.blockedSelection else { return }

        let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(activity.rawValue))
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
    }

    private func removeShield(for activity: DeviceActivityName) {
        let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(activity.rawValue))
        store.shield.applications = nil
        store.shield.applicationCategories = nil
    }

    private func fetchSession(id: String) -> FocusSession? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        guard let container = try? ModelContainer(
            for: Habit.self, HabitCompletion.self, ToDo.self, FocusSession.self,
            configurations: AppGroup.makeModelConfiguration()
        ) else { return nil }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<FocusSession>(predicate: #Predicate { $0.id == uuid })
        return try? context.fetch(descriptor).first
    }
}
