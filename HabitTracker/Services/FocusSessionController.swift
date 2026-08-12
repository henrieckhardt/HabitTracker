import Foundation
import SwiftData

/// The single imperative funnel for starting, stopping, and reconciling
/// on-demand `FocusSession`s. Before this existed, the `activeUntil`/
/// `pendingStart`/`FocusBlockingScheduler` choreography was duplicated
/// across `FocusListView`'s swipe actions and `FocusEditorView`'s control
/// buttons — every call site here replaces one of those copies, so they
/// can't drift from each other (or from `FocusRun` bookkeeping, which
/// didn't exist before either).
///
/// Scheduled (recurring, non-on-demand) sessions are untouched by this type
/// — `FocusEditorView.save()` still calls `FocusBlockingScheduler
/// .reschedule` directly for those, and they don't produce `FocusRun`s (see
/// `FocusRunReconciler`'s doc comment on why that's deliberate for now).
enum FocusSessionController {
    /// Starts `session` (which must be `isOnDemand`) right now.
    ///
    /// - Parameters:
    ///   - durationMinutesOverride: Runs for this many minutes instead of
    ///     `session.durationMinutes`, without changing the template's own
    ///     stored duration — used by `StartFocusSheet`, where the user can
    ///     adjust the length of just this one run.
    ///   - linkedToDo/linkedHabit: The item this run is *for*, if started
    ///     from `DayContentView`'s leading swipe action. Both `nil` for an
    ///     ordinary start from the Focus tab. Passing both is a caller
    ///     error (asserted, not just silently resolved) — a run is linked
    ///     to at most one item.
    ///
    /// Reconciles first so a stale open run from a previous start of this
    /// same session (there shouldn't be one, but see `FocusRunReconciler`'s
    /// invariant-enforcement comment) never lingers past when a fresh one
    /// begins.
    static func start(
        _ session: FocusSession,
        durationMinutesOverride: Int? = nil,
        linkedToDo: ToDo? = nil,
        linkedHabit: Habit? = nil,
        context: ModelContext,
        now: Date = .now
    ) {
        assert(linkedToDo == nil || linkedHabit == nil, "a focus run can be linked to a to-do or a habit, not both")

        reconcile(context: context, now: now)

        let durationMinutes = durationMinutesOverride ?? session.durationMinutes
        let plannedEnd = now.addingTimeInterval(TimeInterval(durationMinutes * 60))
        let label = linkedToDo?.title ?? linkedHabit?.title

        session.pendingStart = nil
        session.activeUntil = plannedEnd
        session.activeToDoID = linkedToDo?.id
        session.activeHabitID = linkedHabit?.id
        session.activeLabel = label

        let run = FocusRun(
            sessionID: session.id,
            sessionTitle: session.title,
            startedAt: now,
            plannedEnd: plannedEnd,
            wasBlockingApps: session.isBlockingEnabled,
            linkedToDoID: linkedToDo?.id,
            linkedHabitID: linkedHabit?.id,
            linkedTitle: label
        )
        context.insert(run)
        session.currentRunID = run.id
        try? context.save()

        FocusBlockingScheduler.startNow(session)

        if linkedToDo != nil || linkedHabit != nil {
            NotificationService.scheduleFocusEnd(for: session, plannedEnd: plannedEnd, linkedToDo: linkedToDo, linkedHabit: linkedHabit)
        }
    }

    /// Schedules `session` to begin `delayMinutes` from now ("Später
    /// starten"). Deliberately does **not** insert a `FocusRun` yet — one
    /// is materialized retroactively by `reconcile` once `pendingStart` has
    /// actually passed, whether that's because this app instance is still
    /// open when it arrives (next `.active` reconcile) or because the app
    /// was closed the whole time and only reopened after the window ended.
    /// (No task-linking parameters: `FocusEditorView`'s delayed-start
    /// control isn't reachable from a linked to-do/habit row today.)
    static func scheduleLater(_ session: FocusSession, delayMinutes: Int, context: ModelContext, now: Date = .now) {
        reconcile(context: context, now: now)

        let start = now.addingTimeInterval(TimeInterval(delayMinutes * 60))
        session.pendingStart = start
        session.activeUntil = start.addingTimeInterval(TimeInterval(session.durationMinutes * 60))
        try? context.save()

        FocusBlockingScheduler.scheduleStart(session, delayMinutes: delayMinutes)
    }

    /// Ends `session` right now — whether it's currently running (an early
    /// stop) or only pending a future start (a cancellation, in which case
    /// there's no open run to close, since one is never created until
    /// `pendingStart` actually arrives).
    static func stop(_ session: FocusSession, context: ModelContext, now: Date = .now) {
        reconcile(context: context, now: now)

        if let runID = session.currentRunID {
            let descriptor = FetchDescriptor<FocusRun>(predicate: #Predicate { $0.id == runID })
            if let openRun = (try? context.fetch(descriptor))?.first, openRun.endedAt == nil {
                openRun.endedAt = now
                openRun.wasEndedEarly = now < openRun.plannedEnd
            }
        }

        NotificationService.cancelFocusEnd(for: session)
        FocusBlockingScheduler.stopNow(session)
        session.activeUntil = nil
        session.pendingStart = nil
        session.activeToDoID = nil
        session.activeHabitID = nil
        session.activeLabel = nil
        session.currentRunID = nil
        try? context.save()
    }

    /// Settles every session/run pair against `now`: closes runs whose
    /// planned end has passed, opens runs retroactively for delayed starts
    /// that have since begun, and clears stale runtime state. Returns the
    /// runs that were newly closed in this call (not ones already closed
    /// before it ran) — callers use that to prompt "focus ended, mark done?"
    /// (see the Focus↔task linking work).
    ///
    /// Loops `FocusRunReconciler.mutations` to a fixed point instead of
    /// calling it once: some transitions need two rounds (a run must exist,
    /// with a real `id`, before it can be closed — see that type's doc
    /// comment). Five iterations is generously more than any real case
    /// needs; the loop still terminates safely if that assumption is ever
    /// wrong, it just stops reconciling early rather than looping forever.
    @discardableResult
    static func reconcile(context: ModelContext, now: Date = .now) -> [FocusRun] {
        var newlyClosed: [FocusRun] = []

        for _ in 0..<5 {
            let sessions = (try? context.fetch(FetchDescriptor<FocusSession>())) ?? []
            let openRuns = (try? context.fetch(
                FetchDescriptor<FocusRun>(predicate: #Predicate { $0.endedAt == nil })
            )) ?? []

            let mutations = FocusRunReconciler.mutations(sessions: sessions, openRuns: openRuns, now: now)
            guard !mutations.isEmpty else { break }

            let sessionsByID = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
            let runsByID = Dictionary(uniqueKeysWithValues: openRuns.map { ($0.id, $0) })

            for mutation in mutations {
                switch mutation {
                case let .openRun(sessionID, sessionTitle, startedAt, plannedEnd, wasBlockingApps, linkedToDoID, linkedHabitID, linkedTitle):
                    let run = FocusRun(
                        sessionID: sessionID,
                        sessionTitle: sessionTitle,
                        startedAt: startedAt,
                        plannedEnd: plannedEnd,
                        wasBlockingApps: wasBlockingApps,
                        linkedToDoID: linkedToDoID,
                        linkedHabitID: linkedHabitID,
                        linkedTitle: linkedTitle
                    )
                    context.insert(run)
                    sessionsByID[sessionID]?.currentRunID = run.id
                case let .closeRun(runID, endedAt, wasEndedEarly):
                    guard let run = runsByID[runID] else { continue }
                    run.endedAt = endedAt
                    run.wasEndedEarly = wasEndedEarly
                    newlyClosed.append(run)
                case let .clearSessionRuntimeState(sessionID):
                    guard let session = sessionsByID[sessionID] else { continue }
                    session.activeUntil = nil
                    session.pendingStart = nil
                    session.activeToDoID = nil
                    session.activeHabitID = nil
                    session.activeLabel = nil
                    session.currentRunID = nil
                    // The window has been settled one way or another by this
                    // point (closed above, or already ended before this app
                    // instance ever observed it) — a still-pending "focus
                    // ended, mark done?" notification for it would be
                    // redundant with the in-app confirmation dialog this
                    // same reconcile pass is about to surface (see
                    // RootTabView), so clear it out too.
                    NotificationService.cancelFocusEnd(for: session)
                case let .discardRun(runID):
                    guard let run = runsByID[runID] else { continue }
                    context.delete(run)
                }
            }

            try? context.save()
        }

        return newlyClosed
    }

    /// Finds (or lazily creates) the shared "Quick Focus" on-demand
    /// template used as the default start target from `StartFocusSheet`.
    /// It's an ordinary, editable `FocusSession` — nameable, its duration
    /// and app-blocking selection changeable from the normal Focus tab —
    /// not a hidden special case. Looked up by the id stored in
    /// `AppSettings.quickFocusSessionID` rather than by title, so renaming
    /// it doesn't spawn a duplicate on the next lookup; if that id no
    /// longer resolves to a live session (archived, or never created yet),
    /// a fresh one is created and the pointer updated.
    static func quickFocusSession(context: ModelContext) -> FocusSession {
        if let id = AppSettings.quickFocusSessionID {
            let descriptor = FetchDescriptor<FocusSession>(predicate: #Predicate { $0.id == id })
            if let existing = (try? context.fetch(descriptor))?.first, !existing.isArchived {
                return existing
            }
        }

        let session = FocusSession(
            title: String(localized: "Quick Focus"),
            startTime: .now,
            endTime: .now,
            isOnDemand: true,
            durationMinutes: AppSettings.defaultFocusDurationMinutes
        )
        context.insert(session)
        try? context.save()
        AppSettings.quickFocusSessionID = session.id
        return session
    }
}
