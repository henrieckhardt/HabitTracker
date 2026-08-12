import Foundation

/// How hard a `FocusSession` makes it to stop early. The whole point of
/// Focus is enforcing a boundary the in-the-moment self would love to skip
/// — so ending a running session is deliberately made *harder* than
/// starting one, via `FocusExitSheet`'s cooling-off period.
///
/// `.hard` is defined but not yet reachable from any UI — no editor lets a
/// user choose it, and `FocusExitPolicy.requirement(for:)`'s `.hard` branch
/// is a placeholder. It exists so a later paid/donation exit tier is a new
/// `case` plus a `FocusExitRequirement` plus a step in `FocusExitSheet`,
/// not a redesign of this type or its call sites.
enum FocusExitDifficulty: String, Codable, CaseIterable {
    case easy
    case hard
}

/// What a session's exit policy actually demands, resolved from its
/// `exitDifficulty`. `FocusExitSheet` renders generically off these three
/// fields rather than switching on `FocusExitDifficulty` itself, which is
/// what makes adding a stricter tier later a data change, not a UI rewrite.
struct FocusExitRequirement: Equatable {
    let coolingOffSeconds: Int
    let requiresReason: Bool
    let requiresPayment: Bool
}

/// Decides how long a stop request has to sit before it's allowed to go
/// through. Pure and stateless — every function takes the session (for its
/// stored `exitDifficulty`/`exitRequestedAt`) and a time, nothing else.
enum FocusExitPolicy {
    static func requirement(for session: FocusSession) -> FocusExitRequirement {
        switch session.exitDifficulty {
        case .easy:
            return FocusExitRequirement(coolingOffSeconds: 60, requiresReason: false, requiresPayment: false)
        case .hard:
            // Unreachable today — see this type's doc comment. Filled in
            // with real values whenever a UI to choose it exists.
            return FocusExitRequirement(coolingOffSeconds: 60, requiresReason: true, requiresPayment: true)
        }
    }

    /// Seconds still left in the cooling-off period. `0` both when it has
    /// fully elapsed and when no exit was ever requested
    /// (`session.exitRequestedAt == nil`) — callers that need to
    /// distinguish "elapsed" from "never started" should check
    /// `exitRequestedAt` directly, as `canExit` does.
    static func remainingSeconds(_ session: FocusSession, at now: Date = .now) -> Int {
        guard let requestedAt = session.exitRequestedAt else { return 0 }
        let requirement = requirement(for: session)
        let remaining = Double(requirement.coolingOffSeconds) - now.timeIntervalSince(requestedAt)
        return max(0, Int(remaining.rounded(.up)))
    }

    /// Whether an in-progress exit request (`exitRequestedAt` set) has
    /// satisfied everything its tier demands. `false` if no exit was ever
    /// requested — there's nothing to let through.
    ///
    /// Also `false` for any tier requiring a reason or payment, regardless
    /// of how much time has passed: `FocusExitSheet` has no step that
    /// collects either today, so a session that somehow ended up on such a
    /// tier must stay unexitable through it rather than silently falling
    /// back to "just wait it out" — the moment `.hard` becomes selectable
    /// in a real editor, this is the one line that needs to change to
    /// match whatever `FocusExitSheet` grows to satisfy it.
    static func canExit(_ session: FocusSession, at now: Date = .now) -> Bool {
        guard session.exitRequestedAt != nil else { return false }
        let requirement = requirement(for: session)
        guard !requirement.requiresReason, !requirement.requiresPayment else { return false }
        return remainingSeconds(session, at: now) <= 0
    }
}
