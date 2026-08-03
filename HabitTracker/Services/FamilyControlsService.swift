import Foundation
import FamilyControls

enum FamilyControlsService {
    static var isAuthorized: Bool {
        AuthorizationCenter.shared.authorizationStatus == .approved
    }

    /// Requests Screen Time authorization for this device's own user
    /// (not parental/child supervision) so the app can present
    /// `FamilyActivityPicker` and apply shields via `ManagedSettingsStore`.
    @discardableResult
    static func requestAuthorization() async -> Bool {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            return isAuthorized
        } catch {
            return false
        }
    }
}
