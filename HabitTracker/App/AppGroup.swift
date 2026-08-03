import Foundation
import SwiftData

/// Shared container identifier used by the main app and the Focus-blocking
/// extensions (FocusShieldMonitor, FocusShieldConfiguration) to access the
/// same SwiftData store.
enum AppGroup {
    static let identifier = "group.com.henrieckhardt.habittracker"

    /// SwiftData ties a store file to the exact schema it was created
    /// with — every process that opens this store (main app,
    /// FocusShieldMonitor, FocusShieldConfiguration) must declare the same
    /// full model list here, even if that process only reads `FocusSession`.
    static func makeModelConfiguration() -> ModelConfiguration {
        ModelConfiguration(groupContainer: .identifier(identifier))
    }
}
