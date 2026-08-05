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

    /// Only used for the "Später starten" control on an already-saved
    /// on-demand session — how far in the future to schedule the start.
    @State private var startDelayMinutes = 10
    /// Ticks so "Läuft noch X Min"/"Startet in X Min" stay current while
    /// this screen is open, same pattern as `FocusListView`.
    @State private var now: Date = .now
    private let controlTimer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    private static var defaultStartTime: Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
    }

    private static var defaultEndTime: Date {
        Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: .now) ?? .now
    }

    private static let durationOptions: [Int] = Array(stride(from: 15, through: 480, by: 15))
    private static let delayOptions: [Int] = Array(stride(from: 5, through: 240, by: 5))

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

    private func formattedMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        switch (hours, mins) {
        case (0, _): return "\(mins) Min"
        case (_, 0): return "\(hours) Std"
        default: return "\(hours) Std \(mins) Min"
        }
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func remainingMinutes(until date: Date) -> Int {
        max(0, Int(date.timeIntervalSince(now) / 60))
    }

    private var isRunning: Bool {
        guard let session = sessionToEdit else { return false }
        return FocusScheduleEngine.isActive(session, at: now)
    }

    private var isPending: Bool {
        guard let session = sessionToEdit, !isRunning, let pendingStart = session.pendingStart else { return false }
        return pendingStart > now
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
                            ForEach(Self.durationOptions, id: \.self) { minutes in
                                Text(formattedMinutes(minutes)).tag(minutes)
                            }
                        }
                        .pickerStyle(.wheel)
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

                if isOnDemand, let session = sessionToEdit {
                    Section("Steuerung") {
                        controlContent(for: session)
                            .padding(.vertical, 6)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                    .onReceive(controlTimer) { date in now = date }
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

    @ViewBuilder
    private func controlContent(for session: FocusSession) -> some View {
        VStack(spacing: 14) {
            if isRunning, let activeUntil = session.activeUntil {
                statCard(icon: "timer", title: "Läuft noch", value: "\(remainingMinutes(until: activeUntil)) Min", tint: .accentColor)
                actionButton("Stop", icon: "stop.fill", tint: .red, role: .destructive) {
                    stopOrCancel(session)
                }
            } else if isPending, let pendingStart = session.pendingStart {
                statCard(icon: "clock", title: "Startet um \(timeText(pendingStart)) Uhr", value: "in \(remainingMinutes(until: pendingStart)) Min", tint: .orange)
                actionButton("Geplanten Start abbrechen", icon: "xmark", tint: .red, role: .destructive) {
                    stopOrCancel(session)
                }
            } else {
                actionButton("Jetzt starten", icon: "play.fill", tint: .green) {
                    startSessionNow(session)
                }

                VStack(spacing: 12) {
                    HStack {
                        Label("Start in", systemImage: "clock")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("", selection: $startDelayMinutes) {
                            ForEach(Self.delayOptions, id: \.self) { minutes in
                                Text(formattedMinutes(minutes)).tag(minutes)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .tint(.orange)
                    }
                    actionButton("Später starten planen", icon: "clock.badge", tint: .orange) {
                        scheduleFutureStart(session, delayMinutes: startDelayMinutes)
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func statCard(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 48, height: 48)
                .background(tint.opacity(0.15))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title2.weight(.semibold))
            }
            Spacer()
        }
        .padding(14)
        .background(tint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func actionButton(_ title: String, icon: String, tint: Color, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: icon)
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 14))
        .tint(tint)
        .controlSize(.large)
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

    private func startSessionNow(_ session: FocusSession) {
        session.pendingStart = nil
        session.activeUntil = Date.now.addingTimeInterval(TimeInterval(session.durationMinutes * 60))
        try? modelContext.save()
        FocusBlockingScheduler.startNow(session)
        dismiss()
    }

    private func scheduleFutureStart(_ session: FocusSession, delayMinutes: Int) {
        let start = Date.now.addingTimeInterval(TimeInterval(delayMinutes * 60))
        session.pendingStart = start
        session.activeUntil = start.addingTimeInterval(TimeInterval(session.durationMinutes * 60))
        try? modelContext.save()
        FocusBlockingScheduler.scheduleStart(session, delayMinutes: delayMinutes)
        dismiss()
    }

    private func stopOrCancel(_ session: FocusSession) {
        FocusBlockingScheduler.stopNow(session)
        session.activeUntil = nil
        session.pendingStart = nil
        try? modelContext.save()
    }
}
