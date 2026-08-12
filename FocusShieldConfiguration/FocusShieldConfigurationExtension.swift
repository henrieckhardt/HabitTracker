import ManagedSettings
import ManagedSettingsUI
import SwiftData
import Foundation
import UIKit

/// Customizes Apple's system shield screen (title/subtitle/button only —
/// layout and colors beyond that are fixed by the OS, see the plan doc's
/// note on why a fully custom screen would need a ShieldActionExtension).
final class FocusShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    private func makeConfiguration() -> ShieldConfiguration {
        let subtitleText: String
        if let session = currentlyActiveSession() {
            let endDate = session.isOnDemand ? session.activeUntil : session.endTime
            // `activeLabel` — set by `FocusSessionController.start` when
            // this session was started for a specific to-do/habit — takes
            // priority over the session's own (template) title, so the
            // shield reads "Steuererklärung · bis 15:30" instead of
            // "Quick Focus · bis 15:30".
            let displayTitle = session.activeLabel ?? session.title
            if let endDate {
                let endText = Self.timeFormatter.string(from: endDate)
                subtitleText = String(localized: "\(displayTitle) · until \(endText)")
            } else {
                subtitleText = displayTitle
            }
        } else {
            subtitleText = String(localized: "This app is blocked during your focus period.")
        }

        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterialDark,
            title: ShieldConfiguration.Label(text: String(localized: "Focus Active"), color: .white),
            subtitle: ShieldConfiguration.Label(text: subtitleText, color: .white.withAlphaComponent(0.8)),
            primaryButtonLabel: ShieldConfiguration.Label(text: String(localized: "Close"), color: .white),
            primaryButtonBackgroundColor: .systemBlue
        )
    }

    private func currentlyActiveSession() -> FocusSession? {
        guard let container = try? ModelContainer(
            for: Habit.self, HabitCompletion.self, ToDo.self, FocusSession.self, FocusRun.self,
            configurations: AppGroup.makeModelConfiguration()
        ) else { return nil }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<FocusSession>(predicate: #Predicate { !$0.isArchived })
        guard let sessions = try? context.fetch(descriptor) else { return nil }
        return FocusScheduleEngine.currentlyActiveSession(in: sessions, at: .now)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}
