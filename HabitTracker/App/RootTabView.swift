import SwiftUI
import SwiftData
import WidgetKit

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    /// The most recently closed *linked* focus run this session hasn't
    /// prompted about yet — drives the "focus ended, mark done?"
    /// confirmation dialog below. Never overwritten while a dialog is
    /// already showing for a previous run (see `.onChange`), so a run
    /// closing mid-prompt doesn't silently swap out what's on screen; it
    /// just waits for the next reconcile.
    @State private var completionPromptRun: FocusRun?

    /// Set when the user taps "Share" in the "Focus Ended" dialog below —
    /// a separate optional rather than reusing `completionPromptRun`
    /// itself, since the confirmation dialog needs to be dismissed (its
    /// `run.linkedTitle ?? run.sessionTitle` job is done) while the share
    /// sheet for that same run is only just starting.
    @State private var runToShare: FocusRun?

    @State private var showingOnboarding = !AppSettings.hasCompletedOnboarding

    var body: some View {
        TabView {
            // Woche is folded into Heute as a segmented Tag/Woche control
            // (see DayContentView/WeekContentView) rather than its own tab.
            DayView()
                .tabItem {
                    Label("Today", systemImage: "calendar")
                }
            HabitListView()
                .tabItem {
                    Label("Habits", systemImage: "checkmark.circle")
                }
            FocusListView()
                .tabItem {
                    Label("Focus", systemImage: "timer")
                }
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
        }
        .task {
            DisplayOrderMigration.run(context: modelContext)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // SwiftData has no cross-process change notification: the
                // widget's ToggleHabitIntent/ToggleToDoIntent write to this
                // same App Group store from the widget extension process,
                // and without this, `mainContext` can keep serving cached
                // objects afterward — a habit checked off from the home
                // screen wouldn't visibly update here until some unrelated
                // mutation happened to touch it. `rollback()` discards no
                // real data (every mutation path in this app already saves
                // immediately), it just forces every `@Query` here to
                // refetch against whatever's actually persisted.
                modelContext.rollback()
                RolloverService.rolloverIfNeeded(context: modelContext)
                // Self-healing safety net: `FocusShieldMonitorExtension`'s
                // `intervalDidStart`/`intervalDidEnd` are known to be
                // unreliable in practice (especially in Xcode-attached
                // Debug builds), so re-sync every Focus session's shield
                // state against the current time whenever the app is
                // opened, instead of relying solely on the extension.
                FocusBlockingScheduler.resyncAll(context: modelContext)
                // Materializes FocusRun history for whatever happened while
                // the app wasn't in the foreground — a delayed start that
                // began, a session that ran to its planned end. See
                // FocusRunReconciler for why this is safe to derive after
                // the fact instead of needing to observe it live.
                let closedRuns = FocusSessionController.reconcile(context: modelContext)
                if AppSettings.promptCompleteAfterFocus, completionPromptRun == nil {
                    completionPromptRun = closedRuns.first { $0.linkedToDoID != nil || $0.linkedHabitID != nil }
                }
            }
            // Widget has no way to observe SwiftData changes itself, so
            // nudge it on every phase change — cheap, and covers both
            // "user just checked something off, then left the app" and
            // "user just came back, rollover may have moved things".
            WidgetCenter.shared.reloadAllTimelines()
        }
        // The in-app half of "focus ended, mark done?" — the out-of-app
        // half is `NotificationService.scheduleFocusEnd`, which reuses the
        // same `COMPLETE_TODO`/`COMPLETE_HABIT` quick actions
        // `NotificationDelegate` already handles. `run.linkedTitle` (not a
        // live fetch of the to-do/habit) is what's shown, so this still
        // reads sensibly even if the linked item was deleted mid-focus.
        .confirmationDialog(
            "Focus Ended",
            isPresented: Binding(
                get: { completionPromptRun != nil },
                set: { isPresented in if !isPresented { completionPromptRun = nil } }
            ),
            presenting: completionPromptRun
        ) { run in
            Button("Mark \(run.linkedTitle ?? run.sessionTitle) as Done") {
                markLinkedItemDone(run)
                completionPromptRun = nil
            }
            Button("Share") {
                runToShare = run
                completionPromptRun = nil
            }
            Button("Not Yet", role: .cancel) {
                completionPromptRun = nil
            }
        } message: { run in
            Text("Your focus session for \"\(run.linkedTitle ?? run.sessionTitle)\" just ended.")
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingContainerView()
        }
        .sheet(item: $runToShare) { run in
            ShareCardPreviewSheet(fileName: "habiz-focus") {
                FocusSessionShareCard(run: run)
            }
        }
    }

    /// Inline for now, matching the same completion logic
    /// `NotificationDelegate.completeHabit`/`.completeToDo` already use —
    /// a natural candidate to route through a shared completion service if
    /// a third/fourth copy of this logic shows up elsewhere later.
    private func markLinkedItemDone(_ run: FocusRun) {
        if let toDoID = run.linkedToDoID {
            let descriptor = FetchDescriptor<ToDo>(predicate: #Predicate { $0.id == toDoID })
            if let toDo = try? modelContext.fetch(descriptor).first, !toDo.isCompleted {
                toDo.isCompleted = true
                toDo.completedAt = .now
                NotificationService.cancelReminder(for: toDo)
            }
        } else if let habitID = run.linkedHabitID {
            let descriptor = FetchDescriptor<Habit>(predicate: #Predicate { $0.id == habitID })
            if let habit = try? modelContext.fetch(descriptor).first {
                let today = Calendar.current.startOfDay(for: .now)
                if habit.completion(on: today) == nil {
                    modelContext.insert(HabitCompletion(date: today, habit: habit))
                }
            }
        }
        try? modelContext.save()
    }
}
