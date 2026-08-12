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
    /// Starts `session` (which must be `isOnDemand`) right now, for
    /// `session.durationMinutes`. Reconciles first so a stale open run from
    /// a previous start of this same session (there shouldn't be one, but
    /// see `FocusRunReconciler`'s invariant-enforcement comment) never lingers
    /// past when a fresh one begins.
    static func start(_ session: FocusSession, context: ModelContext, now: Date = .now) {
        reconcile(context: context, now: now)

        let plannedEnd = now.addingTimeInterval(TimeInterval(session.durationMinutes * 60))
        session.pendingStart = nil
        session.activeUntil = plannedEnd

        let run = FocusRun(
            sessionID: session.id,
            sessionTitle: session.title,
            startedAt: now,
            plannedEnd: plannedEnd,
            wasBlockingApps: session.isBlockingEnabled
        )
        context.insert(run)
        try? context.save()

        FocusBlockingScheduler.startNow(session)
    }

    /// Schedules `session` to begin `delayMinutes` from now ("Später
    /// starten"). Deliberately does **not** insert a `FocusRun` yet — one
    /// is materialized retroactively by `reconcile` once `pendingStart` has
    /// actually passed, whether that's because this app instance is still
    /// open when it arrives (next `.active` reconcile) or because the app
    /// was closed the whole time and only reopened after the window ended.
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

        let sessionID = session.id
        let descriptor = FetchDescriptor<FocusRun>(
            predicate: #Predicate { $0.sessionID == sessionID && $0.endedAt == nil }
        )
        if let openRun = (try? context.fetch(descriptor))?.first {
            openRun.endedAt = now
            openRun.wasEndedEarly = now < openRun.plannedEnd
        }

        FocusBlockingScheduler.stopNow(session)
        session.activeUntil = nil
        session.pendingStart = nil
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
                case let .openRun(sessionID, sessionTitle, startedAt, plannedEnd, wasBlockingApps):
                    let run = FocusRun(
                        sessionID: sessionID,
                        sessionTitle: sessionTitle,
                        startedAt: startedAt,
                        plannedEnd: plannedEnd,
                        wasBlockingApps: wasBlockingApps
                    )
                    context.insert(run)
                case let .closeRun(runID, endedAt, wasEndedEarly):
                    guard let run = runsByID[runID] else { continue }
                    run.endedAt = endedAt
                    run.wasEndedEarly = wasEndedEarly
                    newlyClosed.append(run)
                case let .clearSessionRuntimeState(sessionID):
                    guard let session = sessionsByID[sessionID] else { continue }
                    session.activeUntil = nil
                    session.pendingStart = nil
                case let .discardRun(runID):
                    guard let run = runsByID[runID] else { continue }
                    context.delete(run)
                }
            }

            try? context.save()
        }

        return newlyClosed
    }
}
