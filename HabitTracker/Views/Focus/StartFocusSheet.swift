import SwiftUI
import SwiftData

/// Starts a focus session *for* a specific to-do or habit — reached from
/// `DayContentView`'s leading swipe action. Deliberately small, matching
/// `MoveToDoDateSheet`'s shape: pick which on-demand template to run
/// (defaulting to the shared "Quick Focus" one, see
/// `FocusSessionController.quickFocusSession`), adjust the duration for
/// just this run if needed, tap Start.
///
/// Templates are the `@Query` of standalone on-demand sessions
/// (`isOnDemand && ownerHabit == nil`) — the same set `FocusListView`
/// shows. That's what makes it structurally impossible to ever start a
/// habit's own companion session from here: it isn't in the list to pick.
/// See `FocusSession.activeHabitID`'s doc comment for why that matters.
struct StartFocusSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// What this run is for — exactly one of the two, enforced by
    /// `FocusSessionController.start`'s assertion.
    let itemTitle: String
    let linkedToDo: ToDo?
    let linkedHabit: Habit?

    @Query(
        filter: #Predicate<FocusSession> { $0.isOnDemand && !$0.isArchived && $0.ownerHabit == nil },
        sort: \FocusSession.createdAt
    )
    private var templates: [FocusSession]

    @State private var selectedSessionID: UUID?
    @State private var durationMinutes: Int = AppSettings.defaultFocusDurationMinutes

    private static let durationOptions: [Int] = Array(stride(from: 15, through: 480, by: 15))

    private var selectedSession: FocusSession? {
        guard let selectedSessionID else { return nil }
        return templates.first { $0.id == selectedSessionID }
    }

    private func formattedMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        switch (hours, mins) {
        case (0, _): return String(localized: "\(mins) min")
        case (_, 0): return String(localized: "\(hours) hr")
        default: return String(localized: "\(hours) hr \(mins) min")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(itemTitle, systemImage: linkedHabit != nil ? "repeat" : "checklist")
                        .foregroundStyle(.secondary)
                }

                Section("Template") {
                    Picker("Template", selection: $selectedSessionID) {
                        ForEach(templates) { template in
                            Text(template.title).tag(Optional(template.id))
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Duration") {
                    Picker("Duration", selection: $durationMinutes) {
                        ForEach(Self.durationOptions, id: \.self) { minutes in
                            Text(formattedMinutes(minutes)).tag(minutes)
                        }
                    }
                    .pickerStyle(.wheel)
                }
            }
            .navigationTitle("Start Focus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") { start() }
                        .disabled(selectedSession == nil)
                }
            }
            .task {
                guard selectedSessionID == nil else { return }
                let quickFocus = FocusSessionController.quickFocusSession(context: modelContext)
                selectedSessionID = quickFocus.id
                durationMinutes = quickFocus.durationMinutes
            }
            .onChange(of: selectedSessionID) { _, _ in
                if let session = selectedSession {
                    durationMinutes = session.durationMinutes
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func start() {
        guard let session = selectedSession else { return }
        FocusSessionController.start(
            session,
            durationMinutesOverride: durationMinutes,
            linkedToDo: linkedToDo,
            linkedHabit: linkedHabit,
            context: modelContext
        )
        dismiss()
    }
}
