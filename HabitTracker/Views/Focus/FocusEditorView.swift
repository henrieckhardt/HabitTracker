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
    @State private var showingExitSheet = false

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
        case (0, _): return String(localized: "\(mins) min")
        case (_, 0): return String(localized: "\(hours) hr")
        default: return String(localized: "\(hours) hr \(mins) min")
        }
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
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
                    TextField("e.g. Deep Work", text: $title)
                }

                Section {
                    Picker("Type", selection: $isOnDemand) {
                        Text("Fixed Schedule").tag(false)
                        Text("Start Manually").tag(true)
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text(isOnDemand
                        ? "Runs for a fixed duration once you start it manually."
                        : "Runs automatically in a recurring time window.")
                }

                if isOnDemand {
                    Section("Duration") {
                        Picker("Duration", selection: $durationMinutes) {
                            ForEach(Self.durationOptions, id: \.self) { minutes in
                                Text(formattedMinutes(minutes)).tag(minutes)
                            }
                        }
                        .pickerStyle(.wheel)
                    }
                } else {
                    Section("Time Range") {
                        DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                        DatePicker("End", selection: $endTime, displayedComponents: .hourAndMinute)
                        if !isTimeRangeValid {
                            Text("The time window must be at least \(FocusBlockingScheduler.minimumWindowMinutes) minutes long.")
                                .font(.caption)
                                .foregroundStyle(.red)
                        } else if isOvernight {
                            Text("Runs past midnight into the next day.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Repeat") {
                        RecurrencePickerView(state: $recurrenceState)
                    }
                }

                Section {
                    Toggle("Block Apps", isOn: $blockingEnabled)
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
                                Text("Selected Apps")
                                Spacer()
                                Text(selectionSummary)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("App Blocking")
                } footer: {
                    Text("The selected apps are blocked during the focus period and show a lock screen.")
                }

                if isOnDemand, let session = sessionToEdit {
                    Section("Controls") {
                        controlContent(for: session)
                            .padding(.vertical, 6)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                    .onReceive(controlTimer) { date in now = date }
                }
            }
            .navigationTitle(sessionToEdit == nil ? Text("New Focus") : Text("Edit Focus"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(
                            title.trimmingCharacters(in: .whitespaces).isEmpty
                                || (!isOnDemand && (!recurrenceState.isValid || !isTimeRangeValid))
                        )
                }
            }
            .familyActivityPicker(isPresented: $showingActivityPicker, selection: $appSelection)
            .alert("Access Not Granted", isPresented: $authorizationDeniedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Without Screen Time access, apps can't be blocked. You can allow this in Settings under Screen Time.")
            }
            .sheet(isPresented: $showingExitSheet) {
                if let session = sessionToEdit {
                    FocusExitSheet(session: session)
                }
            }
        }
    }

    @ViewBuilder
    private func controlContent(for session: FocusSession) -> some View {
        VStack(spacing: 14) {
            if isRunning, let activeUntil = session.activeUntil {
                statCard(icon: "timer", title: "Time Remaining", value: "\(remainingMinutes(until: activeUntil)) min", tint: .accentColor)
                // Ending a running session goes through FocusExitSheet's
                // cooling-off period, not a direct stop — see that view's
                // doc comment. "Cancel Scheduled Start" below stays direct:
                // a merely-pending session was never granted a shield, so
                // there's nothing to guard against quitting.
                actionButton("Stop", icon: "stop.fill", tint: .red, role: .destructive) {
                    showingExitSheet = true
                }
            } else if isPending, let pendingStart = session.pendingStart {
                statCard(icon: "clock", title: "Starts at \(timeText(pendingStart))", value: "in \(remainingMinutes(until: pendingStart)) min", tint: .orange)
                actionButton("Cancel Scheduled Start", icon: "xmark", tint: .red, role: .destructive) {
                    stopOrCancel(session)
                }
            } else {
                actionButton("Start Now", icon: "play.fill", tint: .green) {
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
                    actionButton("Schedule Later Start", icon: "clock.badge", tint: .orange) {
                        scheduleFutureStart(session, delayMinutes: startDelayMinutes)
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func statCard(icon: String, title: LocalizedStringKey, value: LocalizedStringKey, tint: Color) -> some View {
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

    private func actionButton(_ title: LocalizedStringKey, icon: String, tint: Color, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 14))
        .tint(tint)
        .controlSize(.large)
    }

    private var selectionSummary: String {
        let count = appSelection.applicationTokens.count + appSelection.categoryTokens.count
        return count == 0 ? String(localized: "None selected") : String(localized: "\(count) selected")
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
        FocusSessionController.start(session, context: modelContext)
        dismiss()
    }

    private func scheduleFutureStart(_ session: FocusSession, delayMinutes: Int) {
        FocusSessionController.scheduleLater(session, delayMinutes: delayMinutes, context: modelContext)
        dismiss()
    }

    private func stopOrCancel(_ session: FocusSession) {
        FocusSessionController.stop(session, context: modelContext)
    }
}
