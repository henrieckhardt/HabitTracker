import SwiftUI

/// The actual point of onboarding, not just a formality: today, Screen Time
/// access gets requested cold from a toggle deep in an editor
/// (`HabitEditorView`/`FocusEditorView`), showing the user a system dialog
/// about *parental controls* with zero context — a decline there is
/// effectively permanent, since `FamilyControlsService.requestAuthorization`
/// can't ask again. Explaining both permissions here first, with an
/// equally-prominent way to skip and no penalty for doing so, is what makes
/// that first ask worth showing. The editors' own cold requests stay as a
/// fallback for anyone who skips this and enables blocking/reminders later.
struct PermissionPrimingView: View {
    @State private var notificationsGranted = false
    @State private var screenTimeGranted = FamilyControlsService.isAuthorized
    @State private var isRequestingNotifications = false
    @State private var isRequestingScreenTime = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.shield")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
            Text("A Couple of Permissions")
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text("Both are optional and can be changed anytime in Settings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 12) {
                PermissionRow(
                    icon: "bell.fill",
                    title: "Notifications",
                    message: "Get reminded about habits and to-dos at the times you choose.",
                    isGranted: notificationsGranted,
                    isRequesting: isRequestingNotifications,
                    action: requestNotifications
                )
                PermissionRow(
                    icon: "hourglass",
                    title: "Screen Time",
                    message: "Lets Focus sessions block distracting apps while they run.",
                    isGranted: screenTimeGranted,
                    isRequesting: isRequestingScreenTime,
                    action: requestScreenTime
                )
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
        .padding(.bottom, 40)
    }

    private func requestNotifications() {
        isRequestingNotifications = true
        Task {
            let granted = await NotificationService.requestAuthorization()
            isRequestingNotifications = false
            notificationsGranted = granted
        }
    }

    private func requestScreenTime() {
        isRequestingScreenTime = true
        Task {
            let granted = await FamilyControlsService.requestAuthorization()
            isRequestingScreenTime = false
            screenTimeGranted = granted
        }
    }
}

private struct PermissionRow: View {
    let icon: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let isGranted: Bool
    let isRequesting: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 40, height: 40)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button(action: action) {
                    if isRequesting {
                        ProgressView()
                    } else {
                        Text("Allow")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isRequesting)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
