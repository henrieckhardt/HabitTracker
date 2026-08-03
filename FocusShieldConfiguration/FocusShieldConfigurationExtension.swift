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
            let endText = Self.timeFormatter.string(from: session.endTime)
            subtitleText = "\(session.title) · bis \(endText) Uhr"
        } else {
            subtitleText = "Diese App ist während deines Fokus-Zeitraums blockiert."
        }

        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterialDark,
            title: ShieldConfiguration.Label(text: "Fokus aktiv", color: .white),
            subtitle: ShieldConfiguration.Label(text: subtitleText, color: .white.withAlphaComponent(0.8)),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Schließen", color: .white),
            primaryButtonBackgroundColor: .systemBlue
        )
    }

    private func currentlyActiveSession() -> FocusSession? {
        guard let container = try? ModelContainer(
            for: Habit.self, HabitCompletion.self, ToDo.self, FocusSession.self,
            configurations: AppGroup.makeModelConfiguration()
        ) else { return nil }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<FocusSession>(predicate: #Predicate { !$0.isArchived })
        guard let sessions = try? context.fetch(descriptor) else { return nil }
        return FocusScheduleEngine.currentlyActiveSession(in: sessions, at: .now)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}
