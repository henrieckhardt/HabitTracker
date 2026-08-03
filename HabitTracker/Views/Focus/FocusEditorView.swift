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
        _blockingEnabled = State(initialValue: session?.isBlockingEnabled ?? false)
        _appSelection = State(initialValue: session?.blockedSelection ?? FamilyActivitySelection())
    }

    /// Only the hour/minute of `startTime`/`endTime` matter; MVP doesn't
    /// support windows that span midnight.
    private var isTimeRangeValid: Bool {
        let calendar = Calendar.current
        let startMinutes = calendar.component(.hour, from: startTime) * 60 + calendar.component(.minute, from: startTime)
        let endMinutes = calendar.component(.hour, from: endTime) * 60 + calendar.component(.minute, from: endTime)
        return endMinutes > startMinutes
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("z.B. Deep Work", text: $title)
                }

                Section("Zeitraum") {
                    DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("Ende", selection: $endTime, displayedComponents: .hourAndMinute)
                    if !isTimeRangeValid {
                        Text("Die Endzeit muss nach der Startzeit liegen.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section("Wiederholung") {
                    RecurrencePickerView(state: $recurrenceState)
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
                                || !recurrenceState.isValid
                                || !isTimeRangeValid
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
            session = existing
        } else {
            session = FocusSession(
                title: trimmedTitle,
                startTime: startTime,
                endTime: endTime,
                recurrenceRule: rule,
                blockedSelection: selection
            )
            modelContext.insert(session)
        }
        try? modelContext.save()
        FocusBlockingScheduler.reschedule(session)
        dismiss()
    }
}
