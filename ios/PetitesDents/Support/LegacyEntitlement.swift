import Foundation
import SwiftData

/// Fair grandfathering: anyone who was already using Petites Dents before the
/// Carnet Souvenirs existed keeps everything, for free and for ever.
///
/// The flag is device-local, written once, and **never** written back to
/// false. The signals below are all traces a real person leaves by using the
/// app; none of them is a key this version writes itself, which is what makes
/// a brand-new install come out as *not* legacy.
@MainActor
enum LegacyEntitlement {
    enum Keys {
        static let legacyUnlocked = "petitesdents.souvenirs.legacyUnlocked"
        static let migrationCompleted = "petitesdents.souvenirs.migrationCompleted"
    }

    /// UserDefaults keys that only exist once the app has actually been used.
    /// `selectedChildID` is written by the profile switcher, and the review
    /// prompt keys by `ReviewPromptTracker` after a tooth is saved.
    static let usageSignalKeys: [String] = [
        "selectedChildID",
        ReviewPromptDefaultsKey.valueEventCount,
        ReviewPromptDefaultsKey.lastPromptedVersion,
        ReviewPromptDefaultsKey.lastPromptDate,
    ]

    /// Runs exactly once per install, as the very first statement after the
    /// model container exists — before the screenshot branch writes
    /// `selectedChildID` and before `ChildProfileMigration` inserts the
    /// default profile, which is why the mere existence of a profile is
    /// deliberately not a signal.
    static func migrateIfNeeded(
        context: ModelContext?,
        userDefaults: UserDefaults = AppDefaults.shared,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) {
        // A UI test or capture run must never touch the real defaults of a
        // development device, and its store is empty anyway.
        guard !LaunchEnvironment.isUITesting(arguments) else { return }
        guard !userDefaults.bool(forKey: Keys.migrationCompleted) else { return }
        if hasExistingUsageSignals(context: context, userDefaults: userDefaults) {
            userDefaults.set(true, forKey: Keys.legacyUnlocked)
        }
        userDefaults.set(true, forKey: Keys.migrationCompleted)
    }

    static func hasExistingUsageSignals(
        context: ModelContext?,
        userDefaults: UserDefaults
    ) -> Bool {
        if usageSignalKeys.contains(where: { userDefaults.object(forKey: $0) != nil }) {
            return true
        }
        return hasExistingStoredData(context: context)
    }

    /// Stored evidence of real use: a saved tooth, a birth date, or a second
    /// child. A default profile inserted by the migration has none of these.
    static func hasExistingStoredData(context: ModelContext?) -> Bool {
        guard let context else { return false }
        if let records = try? context.fetch(FetchDescriptor<ToothRecord>()), !records.isEmpty {
            return true
        }
        guard let profiles = try? context.fetch(FetchDescriptor<ChildProfile>()) else {
            return false
        }
        return profiles.contains {
            $0.birthDate != nil || $0.childID != ChildProfile.primaryChildID
        }
    }

    static func isUnlocked(userDefaults: UserDefaults = AppDefaults.shared) -> Bool {
        userDefaults.bool(forKey: Keys.legacyUnlocked)
    }
}
