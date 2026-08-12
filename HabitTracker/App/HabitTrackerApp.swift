import SwiftUI
import SwiftData
import UserNotifications

@main
struct HabitTrackerApp: App {
    private let modelContainer: ModelContainer?
    private let containerError: Error?
    private let notificationDelegate: NotificationDelegate?

    init() {
        do {
            // Stored in the shared App Group container (not the app's
            // private container) so the FocusShieldMonitor/
            // FocusShieldConfiguration extensions can read FocusSession
            // data directly.
            let container = try ModelContainer(
                for: Habit.self, HabitCompletion.self, ToDo.self, FocusSession.self,
                configurations: AppGroup.makeModelConfiguration()
            )
            modelContainer = container
            containerError = nil

            let delegate = NotificationDelegate(modelContainer: container)
            notificationDelegate = delegate
            UNUserNotificationCenter.current().delegate = delegate
            NotificationService.registerCategories()
        } catch {
            // This used to be `try!`. Every other process sharing this
            // store (FocusShieldMonitor, FocusShieldConfiguration, the
            // widget) already uses `try?` and degrades gracefully when the
            // store won't open — only the main app treated it as fatal. A
            // lightweight-migration failure on a user's device would have
            // meant a launch crash with no way to recover and no way for us
            // to diagnose it, since the app died before any logging or UI
            // existed. Degrade instead: show `StoreRecoveryView`.
            modelContainer = nil
            containerError = error
            notificationDelegate = nil
        }
    }

    var body: some Scene {
        WindowGroup {
            if let modelContainer {
                RootTabView()
                    .modelContainer(modelContainer)
            } else {
                StoreRecoveryView(error: containerError)
            }
        }
        .defaultAppStorage(AppSettings.defaults)
    }
}

/// Shown instead of `RootTabView` when the shared SwiftData store fails to
/// open. There's no local data to fall back to and no in-app retry that
/// wouldn't just fail the same way again, so this offers the two things
/// that actually help: what to try, and a way to reach the developer with
/// the concrete error attached.
private struct StoreRecoveryView: View {
    let error: Error?

    private var mailURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "henrieckiofficial@gmail.com"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Habiz won't open"),
            URLQueryItem(
                name: "body",
                value: "The app failed to load its data:\n\n\(error?.localizedDescription ?? "unknown error")"
            )
        ]
        return components.url
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text("Habiz Couldn't Open Your Data")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("This usually means an update failed partway through. Deleting and reinstalling the app is the most reliable fix, but it will erase everything stored on this device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let mailURL {
                Link(destination: mailURL) {
                    Label("Report This Problem", systemImage: "envelope")
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
            if let error {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
