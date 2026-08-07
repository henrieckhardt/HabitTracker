import SwiftUI

/// Reusable "Erinnerung" section for Habit/ToDo editors: a toggle + time
/// picker that requests notification authorization when enabled.
///
/// The toggle is driven by an outer `Button` rather than relying on
/// `Toggle`'s own gesture recognizer directly — in a plain `Form` `Toggle`,
/// a quick tap (no perceptible movement) can fail to register at all while a
/// drag across the switch does, which made the control feel broken. Wrapping
/// it in a `Button` and making the visual `Toggle` non-interactive makes any
/// tap on the row reliably flip the value.
struct ReminderToggleSection: View {
    @Binding var isEnabled: Bool
    @Binding var time: Date

    var body: some View {
        Section("Reminder") {
            Button {
                isEnabled.toggle()
            } label: {
                HStack {
                    Text("Enable Reminder")
                        .foregroundStyle(.primary)
                    Spacer()
                    Toggle("", isOn: $isEnabled)
                        .labelsHidden()
                        .allowsHitTesting(false)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onChange(of: isEnabled) { _, enabled in
                if enabled {
                    Task { await NotificationService.requestAuthorization() }
                }
            }

            if isEnabled {
                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
            }
        }
    }
}
