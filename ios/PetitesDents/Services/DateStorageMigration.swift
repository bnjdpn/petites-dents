import Foundation
import SwiftData

@MainActor
enum DateStorageMigration {
    static let currentVersion = 1

    static func migrateIfNeeded(in context: ModelContext) throws {
        try ChildProfileMigration.migrateIfNeeded(in: context)
        let profiles = try context.fetch(FetchDescriptor<ChildProfile>())
        let records = try context.fetch(FetchDescriptor<ToothRecord>())
        var changed = false
        for profile in profiles where profile.dateStorageVersion < currentVersion {
            for record in records where record.childID == profile.childID {
                record.teethingDate = record.teethingDate.map {
                    CivilDate.normalizedLegacyLocalMidnight($0)
                }
                record.eruptedDate = record.eruptedDate.map {
                    CivilDate.normalizedLegacyLocalMidnight($0)
                }
            }
            profile.birthDate = profile.birthDate.map {
                CivilDate.normalizedLegacyLocalMidnight($0)
            }
            profile.dateStorageVersion = currentVersion
            changed = true
        }
        if changed {
            try context.save()
        }
    }
}
