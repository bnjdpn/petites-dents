import Foundation
import SwiftData

/// Everything Petites Dents does before the first view appears, in one place
/// so the order can be tested. The order matters: the grandfathering check
/// must read the store and the defaults *before* any migration writes to
/// them, otherwise a brand-new install would look like an old one.
@MainActor
enum AppBootstrap {
    static func start(
        container: ModelContainer,
        userDefaults: UserDefaults = AppDefaults.shared,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) throws {
        let context = container.mainContext

        // 1. Grandfathering, first, always.
        LegacyEntitlement.migrateIfNeeded(
            context: context,
            userDefaults: userDefaults,
            arguments: arguments
        )

        // 2. Capture fixtures, which write both defaults and model objects.
        if LaunchEnvironment.isScreenshotRun(arguments) {
            userDefaults.set(ChildProfile.primaryChildID, forKey: "selectedChildID")
            try ScreenshotDataService.seed(in: context)
        }

        // 3. Schema and storage migrations.
        try ChildProfileMigration.migrateIfNeeded(in: context)
        try DateStorageMigration.migrateIfNeeded(in: context)
    }
}
