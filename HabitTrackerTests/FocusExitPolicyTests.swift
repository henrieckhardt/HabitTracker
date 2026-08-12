import XCTest
@testable import HabitTracker

final class FocusExitPolicyTests: XCTestCase {
    private func makeSession(exitDifficulty: FocusExitDifficulty = .easy) -> FocusSession {
        FocusSession(
            title: "Deep Work",
            startTime: .now,
            endTime: .now,
            isOnDemand: true,
            durationMinutes: 30,
            exitDifficulty: exitDifficulty
        )
    }

    func testCanExitFalseBeforeCoolingOffElapses() {
        let session = makeSession()
        let now = Date.now
        session.exitRequestedAt = now.addingTimeInterval(-30) // 30 of 60 required seconds elapsed

        XCTAssertFalse(FocusExitPolicy.canExit(session, at: now))
        XCTAssertEqual(FocusExitPolicy.remainingSeconds(session, at: now), 30)
    }

    func testCanExitTrueAfterCoolingOffElapses() {
        let session = makeSession()
        let now = Date.now
        session.exitRequestedAt = now.addingTimeInterval(-61)

        XCTAssertTrue(FocusExitPolicy.canExit(session, at: now))
        XCTAssertEqual(FocusExitPolicy.remainingSeconds(session, at: now), 0)
    }

    func testCanExitFalseWhenNoExitEverRequested() {
        let session = makeSession()
        XCTAssertNil(session.exitRequestedAt)

        XCTAssertFalse(FocusExitPolicy.canExit(session, at: .now))
        XCTAssertEqual(FocusExitPolicy.remainingSeconds(session, at: .now), 0)
    }

    func testResumingReturnsToTheNeverRequestedState() {
        // "Fokus fortsetzen" (FocusSessionController.cancelExitRequest)
        // just sets exitRequestedAt back to nil — this confirms that alone
        // is sufficient to make the session fully unexitable again, with
        // no separate "resumed" flag needed.
        let session = makeSession()
        let now = Date.now
        session.exitRequestedAt = now.addingTimeInterval(-90) // long past the cooling-off window
        XCTAssertTrue(FocusExitPolicy.canExit(session, at: now))

        session.exitRequestedAt = nil // simulates cancelExitRequest

        XCTAssertFalse(FocusExitPolicy.canExit(session, at: now))
    }

    func testHardTierNeverExitsThroughTimeAloneEvenLongAfterCoolingOff() {
        // Future-proofing: FocusExitSheet has no step today that collects
        // a reason or a payment, so a `.hard` session must stay blocked
        // indefinitely through it — not just for the first 60 seconds like
        // `.easy` — until real support for that tier exists.
        let session = makeSession(exitDifficulty: .hard)
        let now = Date.now
        session.exitRequestedAt = now.addingTimeInterval(-60 * 60 * 24) // a full day ago

        XCTAssertFalse(FocusExitPolicy.canExit(session, at: now))
    }
}
