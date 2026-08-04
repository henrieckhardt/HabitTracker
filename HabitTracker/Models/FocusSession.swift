import Foundation
import SwiftData
import FamilyControls

@Model
final class FocusSession {
    var id: UUID = UUID()
    var title: String = ""
    var startTime: Date = FocusSession.defaultStartTime()
    var endTime: Date = FocusSession.defaultEndTime()
    var createdAt: Date = Date.now
    var isArchived: Bool = false

    /// `RecurrenceRule` is stored as encoded JSON, not directly — see the
    /// same workaround (and the reason for it) on `Habit.recurrenceRuleData`.
    private var recurrenceRuleData: Data = FocusSession.encode(.daily)

    var recurrenceRule: RecurrenceRule {
        get { FocusSession.decode(recurrenceRuleData) }
        set { recurrenceRuleData = FocusSession.encode(newValue) }
    }

    /// Nil / empty selection means "no app blocking for this session".
    /// Stored as encoded JSON for the same reason as `recurrenceRuleData` —
    /// `FamilyActivitySelection` is Codable but not a SwiftData-friendly
    /// primitive type.
    private var blockedSelectionData: Data?

    var blockedSelection: FamilyActivitySelection? {
        get { blockedSelectionData.flatMap(FocusSession.decodeSelection) }
        set { blockedSelectionData = newValue.flatMap(FocusSession.encodeSelection) }
    }

    var isBlockingEnabled: Bool {
        guard let selection = blockedSelection else { return false }
        return !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty
    }

    /// Set only via `Habit.focusSession`'s inverse relationship when this
    /// session is a habit's companion window; `nil` for standalone sessions
    /// managed directly in `FocusListView`.
    var ownerHabit: Habit?

    /// When `true`, this session is a manually-started template with a fixed
    /// duration (see `durationMinutes`/`activeUntil`) instead of a recurring
    /// daily time window — `startTime`/`endTime`/`recurrenceRule` are unused
    /// in this mode.
    var isOnDemand: Bool = false
    var durationMinutes: Int = 30

    /// Runtime state for an on-demand session: set to `now + duration` when
    /// manually started, `nil` when not currently running. Scheduled
    /// sessions never use this — their "active" state is derived purely from
    /// `startTime`/`endTime`/`recurrenceRule` (see `FocusScheduleEngine`).
    var activeUntil: Date?

    init(
        title: String,
        startTime: Date,
        endTime: Date,
        recurrenceRule: RecurrenceRule = .daily,
        createdAt: Date = .now,
        isArchived: Bool = false,
        blockedSelection: FamilyActivitySelection? = nil,
        isOnDemand: Bool = false,
        durationMinutes: Int = 30
    ) {
        self.id = UUID()
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.recurrenceRuleData = FocusSession.encode(recurrenceRule)
        self.createdAt = createdAt
        self.isArchived = isArchived
        self.blockedSelectionData = blockedSelection.flatMap(FocusSession.encodeSelection)
        self.isOnDemand = isOnDemand
        self.durationMinutes = durationMinutes
    }

    private static func encode(_ rule: RecurrenceRule) -> Data {
        (try? JSONEncoder().encode(rule)) ?? Data()
    }

    private static func decode(_ data: Data) -> RecurrenceRule {
        (try? JSONDecoder().decode(RecurrenceRule.self, from: data)) ?? .daily
    }

    private static func encodeSelection(_ selection: FamilyActivitySelection) -> Data? {
        try? JSONEncoder().encode(selection)
    }

    private static func decodeSelection(_ data: Data) -> FamilyActivitySelection? {
        try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    private static func defaultStartTime() -> Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
    }

    private static func defaultEndTime() -> Date {
        Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: .now) ?? .now
    }
}
