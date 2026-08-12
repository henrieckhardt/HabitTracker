import XCTest
@testable import HabitTracker

final class FocusRunReconcilerTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: 3, hour: hour, minute: minute, second: second))!
    }

    /// An on-demand session — the only kind the reconciler acts on.
    private func makeSession(durationMinutes: Int = 30) -> FocusSession {
        FocusSession(
            title: "Deep Work",
            startTime: date(9, 0),
            endTime: date(9, 30),
            isOnDemand: true,
            durationMinutes: durationMinutes
        )
    }

    private func makeOpenRun(sessionID: UUID, startedAt: Date, plannedEnd: Date) -> FocusRun {
        FocusRun(sessionID: sessionID, sessionTitle: "Deep Work", startedAt: startedAt, plannedEnd: plannedEnd)
    }

    func testExpiredOpenRunClosesAtPlannedEnd() {
        let session = makeSession()
        session.activeUntil = date(9, 30)
        let run = makeOpenRun(sessionID: session.id, startedAt: date(9, 0), plannedEnd: date(9, 30))
        let now = date(9, 35)

        let mutations = FocusRunReconciler.mutations(sessions: [session], openRuns: [run], now: now)

        // Closing the canonical run and clearing the session's now-stale
        // `activeUntil` happen together, in the same pass — there's nothing
        // left still tracking this window once the run is closed.
        XCTAssertEqual(mutations, [
            .closeRun(runID: run.id, endedAt: date(9, 30), wasEndedEarly: false),
            .clearSessionRuntimeState(sessionID: session.id)
        ])
    }

    func testRetroactiveOpenFromElapsedPendingStartStillRunning() {
        let session = makeSession()
        session.pendingStart = date(9, 0) // already passed
        session.activeUntil = date(9, 30) // still in the future relative to `now`
        let now = date(9, 10)

        let mutations = FocusRunReconciler.mutations(sessions: [session], openRuns: [], now: now)

        XCTAssertEqual(mutations, [
            .openRun(
                sessionID: session.id, sessionTitle: "Deep Work", startedAt: date(9, 0), plannedEnd: date(9, 30),
                wasBlockingApps: false, linkedToDoID: nil, linkedHabitID: nil, linkedTitle: nil
            )
        ])
    }

    func testRetroactiveOpenCarriesForwardTheSessionsActiveLink() {
        // A delayed start of a task-linked focus (see StartFocusSheet)
        // should still be attributable to that task even if the retroactive
        // open only materializes later.
        let session = makeSession()
        session.pendingStart = date(9, 0)
        session.activeUntil = date(9, 30)
        let toDoID = UUID()
        session.activeToDoID = toDoID
        session.activeLabel = "Steuererklärung"
        let now = date(9, 10)

        let mutations = FocusRunReconciler.mutations(sessions: [session], openRuns: [], now: now)

        XCTAssertEqual(mutations, [
            .openRun(
                sessionID: session.id, sessionTitle: "Deep Work", startedAt: date(9, 0), plannedEnd: date(9, 30),
                wasBlockingApps: false, linkedToDoID: toDoID, linkedHabitID: nil, linkedTitle: "Steuererklärung"
            )
        ])
    }

    func testFullyElapsedPendingStartOpensAndClearsInOnePass() {
        // Both the delayed start and its window have already passed while
        // the app was closed the whole time — a single `mutations()` call
        // can only open the run (it needs a real id from the caller before
        // it can also be closed), but it should still clear the session's
        // now-stale runtime fields in the same pass.
        let session = makeSession()
        session.pendingStart = date(9, 0)
        session.activeUntil = date(9, 30)
        let now = date(10, 0)

        let mutations = FocusRunReconciler.mutations(sessions: [session], openRuns: [], now: now)

        XCTAssertEqual(mutations, [
            .openRun(
                sessionID: session.id, sessionTitle: "Deep Work", startedAt: date(9, 0), plannedEnd: date(9, 30),
                wasBlockingApps: false, linkedToDoID: nil, linkedHabitID: nil, linkedTitle: nil
            ),
            .clearSessionRuntimeState(sessionID: session.id)
        ])
    }

    func testTwoOpenRunsCollapseToOne() {
        let session = makeSession()
        session.activeUntil = date(9, 45) // matches the canonical (later-started) run, still running
        let stray = makeOpenRun(sessionID: session.id, startedAt: date(8, 0), plannedEnd: date(8, 20))
        let canonical = makeOpenRun(sessionID: session.id, startedAt: date(9, 15), plannedEnd: date(9, 45))
        let now = date(9, 20)

        let mutations = FocusRunReconciler.mutations(sessions: [session], openRuns: [stray, canonical], now: now)

        // The stray run closes at its own planned end; the canonical run —
        // still legitimately running — gets no mutation at all.
        XCTAssertEqual(mutations, [.closeRun(runID: stray.id, endedAt: date(8, 20), wasEndedEarly: false)])
    }

    func testSubMinuteRunIsDiscardedNotClosed() {
        let session = makeSession()
        session.activeUntil = date(9, 0, 25)
        let run = makeOpenRun(sessionID: session.id, startedAt: date(9, 0, 0), plannedEnd: date(9, 0, 25))
        let now = date(9, 5)

        let mutations = FocusRunReconciler.mutations(sessions: [session], openRuns: [run], now: now)

        XCTAssertEqual(mutations, [
            .discardRun(runID: run.id),
            .clearSessionRuntimeState(sessionID: session.id)
        ])
    }

    func testStillRunningSessionProducesNoMutations() {
        let session = makeSession()
        session.activeUntil = date(9, 30)
        let run = makeOpenRun(sessionID: session.id, startedAt: date(9, 0), plannedEnd: date(9, 30))
        let now = date(9, 10) // well before plannedEnd

        let mutations = FocusRunReconciler.mutations(sessions: [session], openRuns: [run], now: now)

        XCTAssertTrue(mutations.isEmpty)
    }

    func testScheduledSessionNeverProducesMutations() {
        // A recurring (non-on-demand) session never sets activeUntil/
        // pendingStart, so it should never match any reconciler condition —
        // scheduled sessions deliberately don't produce FocusRuns yet.
        let session = FocusSession(title: "Morning Routine", startTime: date(9, 0), endTime: date(9, 30))
        let now = date(9, 10)

        let mutations = FocusRunReconciler.mutations(sessions: [session], openRuns: [], now: now)

        XCTAssertTrue(mutations.isEmpty)
    }
}
