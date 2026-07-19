import Foundation
import SwiftData

@MainActor
enum DateStorageMigration {
    static let currentVersion = 1

    static func migrateIfNeeded(in context: ModelContext) throws {
        let profile: ChildProfile
        if let storedProfile = try context.fetch(FetchDescriptor<ChildProfile>())
            .first(where: { $0.childID == ChildProfile.primaryChildID }) {
            profile = storedProfile
        } else {
            profile = ChildProfile(dateStorageVersion: 0)
            context.insert(profile)
        }

        guard profile.dateStorageVersion < currentVersion else { return }

        let records = try context.fetch(FetchDescriptor<ToothRecord>())
        for record in records where record.childID == ToothRecord.primaryChildID {
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
        try context.save()
    }
}
