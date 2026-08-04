import SwiftUI
import SwiftData
import FamilyControls

struct FocusEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// nil when creating a new session.
    private let sessionToEdit: FocusSession?

    @State private var title: String
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var recurrenceState: RecurrenceEditorState
    @State private var isOnDemand: Bool
    @State private var durationMinutes: Int
    @State private var blockingEnabled: Bool
    @State private var appSelection: FamilyActivitySelection
    @State private var showingActivityPicker = false
    @State private var isRequestingAuthorization = false
    @State private var authorizationDeniedAlert = false

    private static var defaultStartTime: Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
    }

    private static var defaultEndTime: Date {
        Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: .now) ?? .now
    }

    init(session: FocusSession? = nil) {
        self.sessionToEdit = session
        _title = State(initialValue: session?.title ?? "")
        _startTime = State(initialValue: session?.startTime ?? Self.defaultStartTime)
        _endTime = State(initialValue: session?.endTime ?? Self.defaultEndTime)
        _recurrenceState = State(initialValue: RecurrenceEditorState.from(session?.recurrenceRule ?? .daily))
        _isOnDemand = State(initialValue: session?.isOnDemand ?? false)
        _durationMinutes = State(initialValue: session?.durationMinutes ?? 30)
        _blockingEnabled = State(initialValue: session?.isBlockingEnabled ?? false)
        _appSelection = State(initialValue: session?.blockedSelection ?? FamilyActivitySelection())
    }

    /// Only the hour/minute of `startTime`/`endTime` matter. An end time
    /// earlier than the start time is valid — it's a window spanning
    /// midnight into the next day (e.g. 22:00–08:00), handled by
    /// `FocusScheduleEngine`/`FocusShieldMonitor`. Windows shorter than
    /// `FocusBlockingScheduler.minimumWindowMinutes` (including exactly
    /// zero-length, start == end) are rejected — anything shorter fails
    /// `DeviceActivityCenter` registration outright.
    private var isTimeRangeValid: Bool {
        windowDurationMinutes >= FocusBlockingScheduler.minimumWindowMinutes
    }

    private var windowDurationMinutes: Int {
        let start = minutes(of: startTime)
        let end = minutes(of: endTime)
        guard start != end else { return 0 }
        return end > start ? end - start : (24 * 60 - start) + end
    }

    private var isOvernight: Bool {
        minutes(of: endTime) < minutes(of: startTime)
    }

    private func minutes(of date: Date) -> Int {
        let calendar = Calendar.current
        return calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("z.B. Deep Work", text: $title)
                }

                Section {
                    Picker("Art", selection: $isOnDemand) {
                        Text("Fester Zeitplan").tag(false)
                        Text("Manuell starten").tag(true)
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text(isOnDemand
                        ? "Läuft für eine feste Dauer, sobald du ihn manuell startest."
                        : "Läuft automatisch in einem wiederkehrenden Zeitfenster.")
                }

                if isOnDemand {
                    Section("Dauer") {
                        Picker("Dauer", selection: $durationMinutes) {
                            Text("15 Min").tag(15)
                            Text("30 Min").tag(30)
                            Text("45 Min").tag(45)
                            Text("60 Min").tag(60)
                            Text("90 Min").tag(90)
                        }
                    }
                } else {
                    Section("Zeitraum") {
                        DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                        DatePicker("Ende", selection: $endTime, displayedComponents: .hourAndMinute)
                        if !isTimeRangeValid {
                            Text("Das Zeitfenster muss mindestens \(FocusBlockingScheduler.minimumWindowMinutes) Minuten lang sein.")
                                .font(.caption)
                                .foregroundStyle(.red)
                        } else if isOvernight {
                            Text("Läuft über Mitternacht bis zum nächsten Tag.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Wiederholung") {
                        RecurrencePickerView(state: $recurrenceState)
                    }
                }

                Section {
                    Toggle("Apps blockieren", isOn: $blockingEnabled)
                        .onChange(of: blockingEnabled) { _, enabled in
                            guard enabled else { return }
                            if FamilyControlsService.isAuthorized {
                                showingActivityPicker = true
                            } else {
                                requestAuthorizationThenShowPicker()
                            }
                        }
                    if blockingEnabled {
                        Button {
                            showingActivityPicker = true
                        } label: {
                            HStack {
                                Text("Ausgewählte Apps")
                                Spacer()
                                Text(selectionSummary)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("App-Blockierung")
                } footer: {
                    Text("Die ausgewählten Apps werden während des Fokus-Zeitraums blockiert und zeigen einen Sperrbildschirm.")
                }
            }
            .navigationTitle(sessionToEdit == nil ? "Neuer Fokus" : "Fokus bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }
                        .disabled(
                            title.trimmingCharacters(in: .whitespaces).isEmpty
                                || (!isOnDemand && (!recurrenceState.isValid || !isTimeRangeValid))
                        )
                }
            }
            .familyActivityPicker(isPresented: $showingActivityPicker, selection: $appSelection)
            .alert("Zugriff nicht erlaubt", isPresented: $authorizationDeniedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Ohne Bildschirmzeit-Zugriff können keine Apps blockiert werden. Du kannst das in den Einstellungen unter Bildschirmzeit erlauben.")
            }
        }
    }

    private var selectionSummary: String {
        let count = appSelection.applicationTokens.count + appSelection.categoryTokens.count
        return count == 0 ? "Keine ausgewählt" : "\(count) ausgewählt"
    }

    private func requestAuthorizationThenShowPicker() {
        isRequestingAuthorization = true
        Task {
            let granted = await FamilyControlsService.requestAuthorization()
            isRequestingAuthorization = false
            if granted {
                showingActivityPicker = true
            } else {
                blockingEnabled = false
                authorizationDeniedAlert = true
            }
        }
    }

    private func save() {
        let rule = recurrenceState.buildRule()
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let selection = blockingEnabled ? appSelection : nil

        let session: FocusSession
        if let existing = sessionToEdit {
            existing.title = trimmedTitle
            existing.startTime = startTime
            existing.endTime = endTime
            existing.recurrenceRule = rule
            existing.blockedSelection = selection
            existing.isOnDemand = isOnDemand
            existing.durationMinutes = durationMinutes
            session = existing
        } else {
            session = FocusSession(
                title: trimmedTitle,
                startTime: startTime,
                endTime: endTime,
                recurrenceRule: rule,
                blockedSelection: selection,
                isOnDemand: isOnDemand,
                durationMinutes: durationMinutes
            )
            modelContext.insert(session)
        }
        try? modelContext.save()
        // On-demand sessions only start monitoring when the user explicitly
        // taps "Start" (see FocusListView) — saving the template itself must
        // not begin blocking, and must clear out any leftover recurring
        // schedule if a session was switched from scheduled to on-demand.
        if isOnDemand {
            FocusBlockingScheduler.stop(session)
        } else {
            FocusBlockingScheduler.reschedule(session)
        }
        dismiss()
    }
}
