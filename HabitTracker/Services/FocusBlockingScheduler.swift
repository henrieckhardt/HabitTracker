import Foundation
import DeviceActivity

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
enum FocusBlockingScheduler {
    static func activityName(for session: FocusSession) -> DeviceActivityName {
        DeviceActivityName(session.id.uuidString)
    }

    /// Call after every save of a `FocusSession` (create, edit, archive).
    static func reschedule(_ session: FocusSession) {
        let center = DeviceActivityCenter()
        let name = activityName(for: session)
        center.stopMonitoring([name])

        guard session.isBlockingEnabled, !session.isArchived else { return }

        let calendar = Calendar.current
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents([.hour, .minute], from: session.startTime),
            intervalEnd: calendar.dateComponents([.hour, .minute], from: session.endTime),
            repeats: true
        )
        try? center.startMonitoring(name, during: schedule)
    }

    /// Call when a session is deleted.
    static func stop(_ session: FocusSession) {
        DeviceActivityCenter().stopMonitoring([activityName(for: session)])
    }
}
