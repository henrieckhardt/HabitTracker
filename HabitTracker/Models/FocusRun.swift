import Foundation
import SwiftData

/// A record that a `FocusSession` actually ran, once. Unlike `FocusSession`
/// itself — which is a reusable template/schedule — a `FocusRun` is a
/// historical fact: it exists so "focus minutes this week" and "sessions
/// completed vs. ended early" are answerable at all, which they aren't
/// today since `FocusSession.activeUntil` is pure runtime state that leaves
/// no trace once a session ends.
///
/// Deliberately **not** a relationship to `FocusSession`/`ToDo`/`Habit`:
/// - `sessionID` is denormalized so history survives deleting the session
///   that produced it, and so this stays out of the object graph those
///   three extension processes fault against.
/// - `linkedToDoID`/`linkedHabitID` mirror `FocusSession.activeToDoID`/
///   `.activeHabitID` (see the Focus↔task linking work) — `ToDo` has zero
///   relationships today, and adding one here would change that entity for
///   every process sharing this store.
///
/// Every property is defaulted or optional, matching the discipline every
/// other `@Model` in this store already follows — that's what keeps
/// SwiftData's lightweight migration working when this type is added to
/// the shared schema.
@Model
final class FocusRun {
    var id: UUID = UUID()
    /// `FocusSession.id` at the time this run happened.
    var sessionID: UUID = UUID()
    /// Denormalized so a run still reads sensibly after its session is
    /// renamed or deleted.
    var sessionTitle: String = ""

    var startedAt: Date = Date.now
    /// Persisted at start, alongside `startedAt` — this is what makes the
    /// run's end *derivable* rather than something that has to be observed
    /// while it happens. See `FocusRunReconciler`.
    var plannedEnd: Date = Date.now
    /// `nil` while the run is still open (in progress, or not yet
    /// reconciled since it ended).
    var endedAt: Date?
    /// `true` when the user stopped the run before `plannedEnd` (via
    /// `FocusExitSheet`), as opposed to it simply reaching its planned end.
    var wasEndedEarly: Bool = false
    var wasBlockingApps: Bool = false

    /// Mirrors `FocusSession.activeToDoID`/`.activeHabitID`/`.activeLabel`
    /// at the time this run started — see that type's doc comments.
    var linkedToDoID: UUID?
    var linkedHabitID: UUID?
    var linkedTitle: String?

    /// Why the user ended this run early, if `wasEndedEarly`. Extension
    /// point for a future "hard" exit tier (see `FocusExitPolicy`) that
    /// requires a reason; always `nil` for the current "easy" tier.
    var exitReason: String?

    /// `"manual"` (the only value written today) or `"scheduled"` — reserved
    /// for a possible future projection of elapsed recurring time windows
    /// into runs, deliberately not built yet (see the coherence plan).
    var sourceRaw: String = "manual"

    /// `true` while this run has neither ended nor been reconciled as
    /// closed yet.
    var isOpen: Bool { endedAt == nil }

    init(
        sessionID: UUID,
        sessionTitle: String,
        startedAt: Date,
        plannedEnd: Date,
        endedAt: Date? = nil,
        wasEndedEarly: Bool = false,
        wasBlockingApps: Bool = false,
        linkedToDoID: UUID? = nil,
        linkedHabitID: UUID? = nil,
        linkedTitle: String? = nil,
        exitReason: String? = nil,
        sourceRaw: String = "manual"
    ) {
        self.id = UUID()
        self.sessionID = sessionID
        self.sessionTitle = sessionTitle
        self.startedAt = startedAt
        self.plannedEnd = plannedEnd
        self.endedAt = endedAt
        self.wasEndedEarly = wasEndedEarly
        self.wasBlockingApps = wasBlockingApps
        self.linkedToDoID = linkedToDoID
        self.linkedHabitID = linkedHabitID
        self.linkedTitle = linkedTitle
        self.exitReason = exitReason
        self.sourceRaw = sourceRaw
    }
}
