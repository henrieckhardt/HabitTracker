import SwiftUI
import SwiftData

/// The gate between tapping Stop and a focus session actually ending.
/// Deliberately makes ending early *harder* than starting — the whole
/// point of Focus is enforcing a boundary the in-the-moment self would
/// love to skip. `FocusExitPolicy` decides how hard; today that's always a
/// 60-second, free, no-questions-asked cooling-off period ("easy"), but
/// the view renders generically off `FocusExitRequirement`'s fields, so a
/// later "hard" tier (a reason, a donation) is a data change on that type
/// plus a step here, not a redesign — see `FocusExitPolicy`.
///
/// The shield stays active for the entire cooling-off period — nothing
/// here touches `FocusBlockingScheduler` until the user actually confirms.
/// Sitting and watching a countdown is a real, if small, cost the
/// in-the-moment self has to pay before quitting wins; that's the whole
/// mechanism.
///
/// **Leaving the app clears the request and the focus just keeps
/// running — deliberately, not a bug.** Backgrounding, swiping the sheet
/// away, anything that ends this view's lifetime cancels the cooling-off
/// period rather than pausing it. That's actually the *stronger* design:
/// escaping the app doesn't get you anywhere, since nothing was
/// accomplished by leaving — you still have to come back and sit through
/// the full countdown in the foreground. It also sidesteps a real problem
/// a "pause in background" design would have: no other process could
/// reliably clear the shield at exactly the right moment once the
/// countdown resumes while this view isn't around to host it.
struct FocusExitSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let session: FocusSession

    @State private var now: Date = .now
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var requirement: FocusExitRequirement {
        FocusExitPolicy.requirement(for: session)
    }

    private var remainingSeconds: Int {
        FocusExitPolicy.remainingSeconds(session, at: now)
    }

    private var progress: Double {
        guard requirement.coolingOffSeconds > 0 else { return 1 }
        let elapsed = Double(requirement.coolingOffSeconds - remainingSeconds)
        return min(1, max(0, elapsed / Double(requirement.coolingOffSeconds)))
    }

    private var canExit: Bool {
        FocusExitPolicy.canExit(session, at: now)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: progress)
                    Text("\(remainingSeconds)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                }
                .frame(width: 160, height: 160)
                .padding(.top, 8)

                VStack(spacing: 8) {
                    Text("Still Focusing?")
                        .font(.title2.bold())
                    Text("Your focus session for \"\(session.activeLabel ?? session.title)\" is still running.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        resumeFocus()
                    } label: {
                        Text("Keep Focusing")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button(role: .destructive) {
                        endFocus()
                    } label: {
                        Text("End Focus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(!canExit)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            // Unconditional, not "only if nil": every appearance of this
            // sheet is a fresh tap of Stop and must start a fresh
            // cooling-off period. A guarded version — only setting this
            // when it was `nil` — has a real hole: if the app is
            // force-quit (not just backgrounded) while this sheet is up,
            // the process dies before `onDisappear`/`scenePhase` can clear
            // the field, so the stale, minutes-old timestamp survives in
            // the persisted store. Reopening the sheet later would then
            // read `remainingSeconds` as already elapsed, skipping the
            // cooling-off period entirely — exactly what this view exists
            // to prevent.
            FocusSessionController.requestExit(session, context: modelContext)
        }
        .onDisappear {
            // Covers "Keep Focusing" (already cleared explicitly below,
            // this is a harmless no-op by then) and swiping the sheet away.
            // Backgrounding the app does **not** trigger this — SwiftUI
            // keeps a presented sheet's view hierarchy alive while
            // backgrounded, it just stops rendering/updating it — which is
            // exactly why `scenePhase` below exists as a second path.
            if session.exitRequestedAt != nil {
                FocusSessionController.cancelExitRequest(session, context: modelContext)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // The other half of "leaving the app cancels the request,
            // deliberately" (see this type's doc comment) — `onDisappear`
            // alone doesn't fire on backgrounding, only on this view
            // actually leaving the hierarchy. Also dismiss, rather than
            // leaving a now-meaningless "cooling off" sheet sitting behind
            // whatever the user returns to — coming back always means
            // tapping Stop again and starting the countdown fresh.
            guard newPhase != .active, session.exitRequestedAt != nil else { return }
            FocusSessionController.cancelExitRequest(session, context: modelContext)
            dismiss()
        }
        .onReceive(timer) { date in now = date }
    }

    private func resumeFocus() {
        FocusSessionController.cancelExitRequest(session, context: modelContext)
        dismiss()
    }

    private func endFocus() {
        guard canExit else { return }
        FocusSessionController.stop(session, context: modelContext)
        dismiss()
    }
}
