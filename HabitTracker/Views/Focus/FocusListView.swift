import SwiftUI
import SwiftData

struct FocusListView: View {
    @Environment(\.modelContext) private var modelContext
    // Sessions owned by a Habit (`ownerHabit != nil`) are companion windows
    // managed entirely from `HabitEditorView` — they're deliberately hidden
    // here so there's never a second, independently-editable copy of the
    // habit's own recurrence rule.
    @Query(
        filter: #Predicate<FocusSession> { !$0.isArchived && $0.ownerHabit == nil },
        sort: \FocusSession.createdAt
    )
    private var sessions: [FocusSession]

    @State private var showingAddSession = false
    @State private var sessionToEdit: FocusSession?
    @State private var now: Date = .now

    /// Ticks periodically so the "currently active" banner/highlight stay
    /// correct without requiring user interaction.
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var activeSession: FocusSession? {
        FocusScheduleEngine.currentlyActiveSession(in: sessions, at: now)
    }

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No Focus Sessions",
                        systemImage: "timer",
                        description: Text("Create your first focus session.")
                    )
                } else {
                    // The active-session banner is deliberately kept out of
                    // the List's own ViewBuilder (as a safeAreaInset instead
                    // of a conditional Section) — a conditionally-appearing
                    // Section inside the List broke tap handling on the
                    // sibling Section's rows (same class of List hit-testing
                    // bug as RecurrencePickerView; see its comment).
                    List {
                        ForEach(sessions) { session in
                            let isRunning = session.id == activeSession?.id
                            let isPending = session.isOnDemand && !isRunning && (session.pendingStart.map { $0 > now } ?? false)
                            Button {
                                sessionToEdit = session
                            } label: {
                                FocusRow(session: session, isActive: isRunning, isPending: isPending, now: now)
                            }
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button("Archive", systemImage: "archivebox") {
                                    session.isArchived = true
                                    try? modelContext.save()
                                    FocusBlockingScheduler.stop(session)
                                }
                                .tint(.orange)

                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    FocusBlockingScheduler.stop(session)
                                    modelContext.delete(session)
                                    try? modelContext.save()
                                }
                            }
                            .swipeActions(edge: .leading) {
                                if session.isOnDemand {
                                    if isRunning {
                                        Button("Stop", systemImage: "stop.fill") {
                                            FocusSessionController.stop(session, context: modelContext)
                                        }
                                        .tint(.red)
                                    } else if isPending {
                                        Button("Cancel", systemImage: "xmark") {
                                            FocusSessionController.stop(session, context: modelContext)
                                        }
                                        .tint(.orange)
                                    } else {
                                        Button("Start", systemImage: "play.fill") {
                                            FocusSessionController.start(session, context: modelContext)
                                        }
                                        .tint(.green)
                                    }
                                }
                            }
                        }
                    }
                    .safeAreaInset(edge: .top) {
                        if let activeSession {
                            ActiveFocusBanner(session: activeSession)
                                .padding()
                                .background(.bar)
                        }
                    }
                }
            }
            .navigationTitle("Focus")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSession = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSession) {
                FocusEditorView()
            }
            .sheet(item: $sessionToEdit) { session in
                FocusEditorView(session: session)
            }
            .onReceive(timer) { date in
                now = date
            }
        }
    }
}

private func timeText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = .autoupdatingCurrent
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter.string(from: date)
}

private struct ActiveFocusBanner: View {
    let session: FocusSession

    private var endText: String {
        let endDate = session.isOnDemand ? session.activeUntil : session.endTime
        guard let endDate else { return "" }
        return String(localized: "Until \(timeText(endDate))")
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "timer")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("Currently active: \(session.title)")
                    .font(.subheadline.weight(.semibold))
                Text(endText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

private struct FocusRow: View {
    let session: FocusSession
    let isActive: Bool
    let isPending: Bool
    let now: Date

    private var subtitle: String {
        guard session.isOnDemand else {
            return "\(timeText(session.startTime))–\(timeText(session.endTime)) · \(session.recurrenceRule.summaryText)"
        }
        if isActive, let activeUntil = session.activeUntil {
            let remainingMinutes = max(0, Int(activeUntil.timeIntervalSince(now) / 60))
            return String(localized: "\(remainingMinutes) min remaining")
        }
        if isPending, let pendingStart = session.pendingStart {
            let remainingMinutes = max(0, Int(pendingStart.timeIntervalSince(now) / 60))
            return String(localized: "Starts in \(remainingMinutes) min (\(timeText(pendingStart)))")
        }
        return String(localized: "\(session.durationMinutes) min · Manual")
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.isOnDemand ? (isPending ? "clock" : "play.circle") : "timer")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isActive ? Color.white : Color.accentColor)
                .frame(width: 36, height: 36)
                .background(isActive ? Color.accentColor : Color.accentColor.opacity(0.15))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }
}
