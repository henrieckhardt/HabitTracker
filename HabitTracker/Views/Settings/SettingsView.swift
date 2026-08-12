import SwiftUI
import SwiftData
import UserNotifications
import FamilyControls

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Plain `@State` mirroring `AppSettings`, not `@AppStorage` — this
    // screen is reached through a `.sheet`, and `@AppStorage` without an
    // explicit `store:` depends on the `.defaultAppStorage` environment
    // value propagating all the way through that presentation. Every other
    // read/write of `AppSettings` in this codebase goes through its static
    // properties directly (see `HabitEditorView`'s `defaultReminderTime`),
    // so this does the same instead of introducing the one place that
    // could silently drift onto `.standard` and stop actually affecting
    // `CalendarProvider`/the widget/the intents that read the App Group
    // suite directly.
    @State private var weekStartWeekday = AppSettings.weekStartWeekday
    @State private var defaultReminderMinutes = AppSettings.defaultReminderMinutes
    @State private var defaultFocusDurationMinutes = AppSettings.defaultFocusDurationMinutes
    @State private var promptCompleteAfterFocus = AppSettings.promptCompleteAfterFocus

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var screenTimeStatus: AuthorizationStatus = AuthorizationCenter.shared.authorizationStatus

    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteFinalConfirmation = false
    @State private var showingPrivacyPolicy = false
    @State private var exportURL: URL?

    private static let durationOptions: [Int] = Array(stride(from: 15, through: 480, by: 15))

    /// `AppSettings.defaultReminderMinutes` is minutes-since-midnight, not a
    /// `Date` — a `DatePicker` needs a `Date` binding, so this maps between
    /// them using today's date as an arbitrary carrier (only hour/minute are
    /// ever read back out).
    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: defaultReminderMinutes / 60, minute: defaultReminderMinutes % 60, second: 0, of: .now) ?? .now
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                defaultReminderMinutes = (comps.hour ?? 9) * 60 + (comps.minute ?? 0)
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("General") {
                    Picker("Week Starts On", selection: $weekStartWeekday) {
                        Text("Sunday").tag(1)
                        Text("Monday").tag(2)
                    }
                    DatePicker("Default Reminder Time", selection: reminderTimeBinding, displayedComponents: .hourAndMinute)
                    Picker("Default Focus Duration", selection: $defaultFocusDurationMinutes) {
                        ForEach(Self.durationOptions, id: \.self) { minutes in
                            Text(formattedMinutes(minutes)).tag(minutes)
                        }
                    }
                    Toggle("Ask to Complete After Focus", isOn: $promptCompleteAfterFocus)
                }

                Section {
                    permissionRow(
                        icon: "bell.fill",
                        title: "Notifications",
                        isGranted: notificationStatus == .authorized,
                        isDenied: notificationStatus == .denied,
                        request: requestNotifications
                    )
                    permissionRow(
                        icon: "hourglass",
                        title: "Screen Time",
                        isGranted: screenTimeStatus == .approved,
                        isDenied: screenTimeStatus == .denied,
                        request: requestScreenTime
                    )
                } header: {
                    Text("Permissions")
                }

                Section("Data") {
                    if let exportURL {
                        ShareLink("Export Data", item: exportURL)
                    } else {
                        Button("Export Data") {
                            self.exportURL = DataExportService.exportURL(context: modelContext)
                        }
                    }
                    Button("Delete All Data", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                }

                Section {
                    NavigationLink("Archive") {
                        ArchivedItemsView()
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersionText)
                            .foregroundStyle(.secondary)
                    }
                    Button("Privacy Policy") {
                        showingPrivacyPolicy = true
                    }
                    Link(destination: URL(string: "mailto:henrieckiofficial@gmail.com")!) {
                        Text("Contact")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                notificationStatus = await currentNotificationStatus()
            }
            .onChange(of: weekStartWeekday) { _, newValue in
                AppSettings.weekStartWeekday = newValue
            }
            .onChange(of: defaultReminderMinutes) { _, newValue in
                AppSettings.defaultReminderMinutes = newValue
            }
            .onChange(of: defaultFocusDurationMinutes) { _, newValue in
                AppSettings.defaultFocusDurationMinutes = newValue
            }
            .onChange(of: promptCompleteAfterFocus) { _, newValue in
                AppSettings.promptCompleteAfterFocus = newValue
            }
            .navigationDestination(isPresented: $showingPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .confirmationDialog(
                "Delete All Data?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Continue", role: .destructive) {
                    showingDeleteFinalConfirmation = true
                }
            } message: {
                Text("This permanently deletes every habit, to-do, and focus session. This can't be undone.")
            }
            .confirmationDialog(
                "Are You Absolutely Sure?",
                isPresented: $showingDeleteFinalConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Everything", role: .destructive) {
                    DataDeletionService.deleteAllData(context: modelContext)
                    dismiss()
                }
            } message: {
                Text("There is no way to recover this data afterward.")
            }
        }
    }

    @ViewBuilder
    private func permissionRow(icon: String, title: LocalizedStringKey, isGranted: Bool, isDenied: Bool, request: @escaping () -> Void) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            if isGranted {
                Text("Allowed")
                    .foregroundStyle(.secondary)
            } else if isDenied {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } else {
                Button("Allow", action: request)
            }
        }
    }

    private func requestNotifications() {
        Task {
            _ = await NotificationService.requestAuthorization()
            notificationStatus = await currentNotificationStatus()
        }
    }

    private func requestScreenTime() {
        Task {
            _ = await FamilyControlsService.requestAuthorization()
            screenTimeStatus = AuthorizationCenter.shared.authorizationStatus
        }
    }

    private func currentNotificationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
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

    private var appVersionText: String {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(shortVersion) (\(buildNumber))"
    }
}
