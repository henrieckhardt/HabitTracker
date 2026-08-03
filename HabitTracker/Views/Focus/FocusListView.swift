import SwiftUI
import SwiftData

struct FocusListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<FocusSession> { !$0.isArchived },
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
                        "Keine Fokus-Zeiträume",
                        systemImage: "timer",
                        description: Text("Lege deinen ersten Fokus-Zeitraum an.")
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
                            Button {
                                sessionToEdit = session
                            } label: {
                                FocusRow(session: session, isActive: session.id == activeSession?.id)
                            }
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button("Archivieren", systemImage: "archivebox") {
                                    session.isArchived = true
                                    try? modelContext.save()
                                }
                                .tint(.orange)

                                Button("Löschen", systemImage: "trash", role: .destructive) {
                                    modelContext.delete(session)
                                    try? modelContext.save()
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
            .navigationTitle("Fokus")
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
    formatter.locale = Locale(identifier: "de_DE")
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter.string(from: date)
}

private struct ActiveFocusBanner: View {
    let session: FocusSession

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "timer")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("Gerade aktiv: \(session.title)")
                    .font(.subheadline.weight(.semibold))
                Text("Bis \(timeText(session.endTime)) Uhr")
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

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "timer")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isActive ? Color.white : Color.accentColor)
                .frame(width: 36, height: 36)
                .background(isActive ? Color.accentColor : Color.accentColor.opacity(0.15))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .foregroundStyle(.primary)
                Text("\(timeText(session.startTime))–\(timeText(session.endTime)) · \(session.recurrenceRule.summaryText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }
}
