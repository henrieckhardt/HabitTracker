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

    /// Runtime state for an on-demand session: set to the window's end
    /// (`start + duration`) when started or scheduled, `nil` when idle.
    /// Scheduled sessions never use this — their "active" state is derived
    /// purely from `startTime`/`endTime`/`recurrenceRule` (see
    /// `FocusScheduleEngine`).
    var activeUntil: Date?

    /// Non-nil while an on-demand session has been scheduled to start in
    /// the future but hasn't begun yet ("Später starten"). `nil` for an
    /// immediate start, or once the window has actually begun — from that
    /// point "active" is purely `date < activeUntil`, same as before this
    /// field existed.
    var pendingStart: Date?

    // MARK: - Task linking (set only while this run is active)
    //
    // All four fields below are pure runtime state, exactly like
    // `activeUntil`/`pendingStart` above: they're set when a linked focus
    // starts and cleared the moment it ends — the permanent record of what a
    // run was linked to lives in `FocusRun.linkedToDoID`/`.linkedHabitID`/
    // `.linkedTitle` instead. `FocusSessionController` is the only writer.
    //
    // A `ToDo`/`Habit` `id` is stored rather than a `@Relationship`: `ToDo`
    // has zero relationships anywhere else in this schema, and adding one
    // here would change that entity for every process sharing this store
    // (see `AppGroup`'s doc comment) for a field that's empty outside of an
    // active linked run.

    /// The `ToDo` this session is currently running for, if started from
    /// one (see `DayContentView`'s leading swipe action).
    var activeToDoID: UUID?

    /// The `Habit` this session is currently running for.
    ///
    /// ⚠️ This is **never** set on a habit's own companion session
    /// (`ownerHabit != nil`, managed by `HabitEditorView`'s time-window
    /// section) — starting a focus *for* a habit always runs the shared
    /// "Quick Focus" on-demand template (or another user-chosen standalone
    /// template) instead, with this field pointing at the habit. Running an
    /// on-demand start directly on a companion session would tear down and
    /// replace its repeating `DeviceActivitySchedule` registration
    /// (`FocusBlockingScheduler.registerOneOffSchedule` calls
    /// `stopMonitoring` first), permanently breaking the habit's daily
    /// time window. `StartFocusSheet` only ever offers standalone sessions
    /// (`ownerHabit == nil`), which makes this impossible by construction
    /// rather than a runtime check this comment would otherwise have to ask
    /// you to trust.
    var activeHabitID: UUID?

    /// Denormalized title of whatever `activeToDoID`/`activeHabitID` points
    /// at, captured at start time — lets the shield subtitle
    /// (`FocusShieldConfigurationExtension`) and the active-focus banner
    /// show "Steuererklärung · bis 15:30" without either process faulting a
    /// relationship to resolve it.
    var activeLabel: String?

    /// `FocusRun.id` of the run currently tracking this session's active
    /// window, so `FocusSessionController.stop`/`.reconcile` can find it in
    /// O(1) instead of a fetch-by-predicate.
    var currentRunID: UUID?

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
