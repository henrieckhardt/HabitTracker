import Foundation

/// Derives what needs to change about `FocusRun`/`FocusSession` state,
/// given a snapshot of both at some `now`. Pure and side-effect free — it
/// never touches a `ModelContext` — so it's testable with plain constructed
/// objects, same as `FocusScheduleEngineTests` does for `FocusSession`.
///
/// The core idea this encodes: a focus run's *end* isn't something that has
/// to be observed while it happens. `startedAt`/`plannedEnd` are persisted
/// the moment a session starts, so the end is already fully determined —
/// reconciliation just materializes it, whenever the app next looks
/// (immediately, or three days later, doesn't matter). That's what lets
/// `FocusSessionController.reconcile` replace `FocusShieldMonitorExtension
/// .intervalDidEnd`, which is both documented-unreliable in this codebase
/// (see `FocusBlockingScheduler`) and structurally unable to fire at all
/// for a session with no app blocking enabled (`registerOneOffSchedule`
/// never registers monitoring for one — see its early-return there).
///
/// `FocusSessionController.reconcile` calls `mutations(...)` in a loop
/// until it returns empty, applying each batch before the next call. That
/// lets a single reconcile pass settle a multi-step transition — e.g. a
/// delayed start whose window both began *and* already elapsed while the
/// app was closed needs to be opened, then closed, which takes two rounds
/// once the opened run actually exists and has an id.
enum FocusRunReconciler {
    /// Below this, a run is treated as noise (an accidental start
    /// immediately followed by a stop, a scheduled start that elapsed and
    /// ended within the same instant) and discarded rather than recorded.
    static let minimumLoggedMinutes = 1

    enum Mutation: Equatable {
        case openRun(
            sessionID: UUID,
            sessionTitle: String,
            startedAt: Date,
            plannedEnd: Date,
            wasBlockingApps: Bool,
            linkedToDoID: UUID?,
            linkedHabitID: UUID?,
            linkedTitle: String?
        )
        case closeRun(runID: UUID, endedAt: Date, wasEndedEarly: Bool)
        case clearSessionRuntimeState(sessionID: UUID)
        case discardRun(runID: UUID)
    }

    static func mutations(sessions: [FocusSession], openRuns: [FocusRun], now: Date = .now) -> [Mutation] {
        sessions.flatMap { mutations(for: $0, openRuns: openRuns, now: now) }
    }

    private static func mutations(for session: FocusSession, openRuns: [FocusRun], now: Date) -> [Mutation] {
        var result: [Mutation] = []

        let sessionOpenRuns = openRuns
            .filter { $0.sessionID == session.id }
            .sorted { $0.startedAt < $1.startedAt }

        // Invariant: at most one open run per session. This "shouldn't
        // happen" in normal operation (every path that opens a run either
        // goes through `FocusSessionController.start` — which reconciles
        // first — or this reconciler itself, which never opens a second run
        // while one already exists), but if it ever does (a stale
        // in-memory `FocusSession` mutated by two call sites in the same
        // pass, a manual DB edit during development), keep the most
        // recently started run and close out the rest at their own planned
        // end rather than leaving them open forever.
        let strayRuns = sessionOpenRuns.dropLast()
        for stray in strayRuns {
            result.append(closeOrDiscard(runID: stray.id, startedAt: stray.startedAt, endedAt: stray.plannedEnd, wasEndedEarly: false))
        }
        let canonical = sessionOpenRuns.last

        if let canonical, canonical.plannedEnd <= now {
            result.append(closeOrDiscard(runID: canonical.id, startedAt: canonical.startedAt, endedAt: canonical.plannedEnd, wasEndedEarly: false))
        }

        // Retroactive open: nothing is tracking this session's current
        // window as a run yet. Two ways that happens:
        //  - a delayed start ("Später starten") whose `pendingStart` has
        //    now passed — normal for an on-demand session scheduled while
        //    the app was backgrounded or closed the whole time.
        //  - an immediate start with no `pendingStart` but `activeUntil`
        //    still set and no run for it — shouldn't happen given
        //    `FocusSessionController.start` always inserts one, but this is
        //    a self-healing fallback in the same spirit as
        //    `FocusBlockingScheduler.resyncAll`. `startedAt` is estimated
        //    from `activeUntil - durationMinutes`.
        if canonical == nil {
            if let pendingStart = session.pendingStart, pendingStart <= now, let activeUntil = session.activeUntil {
                result.append(.openRun(
                    sessionID: session.id,
                    sessionTitle: session.title,
                    startedAt: pendingStart,
                    plannedEnd: activeUntil,
                    wasBlockingApps: session.isBlockingEnabled,
                    linkedToDoID: session.activeToDoID,
                    linkedHabitID: session.activeHabitID,
                    linkedTitle: session.activeLabel
                ))
            } else if session.pendingStart == nil, session.isOnDemand, let activeUntil = session.activeUntil {
                let estimatedStart = activeUntil.addingTimeInterval(-TimeInterval(session.durationMinutes * 60))
                result.append(.openRun(
                    sessionID: session.id,
                    sessionTitle: session.title,
                    startedAt: estimatedStart,
                    plannedEnd: activeUntil,
                    wasBlockingApps: session.isBlockingEnabled,
                    linkedToDoID: session.activeToDoID,
                    linkedHabitID: session.activeHabitID,
                    linkedTitle: session.activeLabel
                ))
            }
        }

        // Once the window has definitively ended and there's no canonical
        // run still legitimately open for it, the session's runtime fields
        // (`activeUntil`/`pendingStart`) are stale — clear them so the UI
        // (and `FocusScheduleEngine.isActive`) agree the session is idle.
        // Scheduled (non-on-demand) sessions never set `activeUntil`, so
        // this is a no-op for them.
        let canonicalStillOpen = canonical.map { $0.plannedEnd > now } ?? false
        if let activeUntil = session.activeUntil, activeUntil <= now, !canonicalStillOpen {
            result.append(.clearSessionRuntimeState(sessionID: session.id))
        }

        return result
    }

    private static func closeOrDiscard(runID: UUID, startedAt: Date, endedAt: Date, wasEndedEarly: Bool) -> Mutation {
        let durationSeconds = endedAt.timeIntervalSince(startedAt)
        guard durationSeconds >= Double(minimumLoggedMinutes) * 60 else {
            return .discardRun(runID: runID)
        }
        return .closeRun(runID: runID, endedAt: endedAt, wasEndedEarly: wasEndedEarly)
    }
}
