import Foundation
import SwiftData

@MainActor
enum ChildProfileMigration {
    static func migrateIfNeeded(
        in context: ModelContext,
        defaultName: String = String(localized: "profile.default_name")
    ) throws {
        var profiles = try context.fetch(FetchDescriptor<ChildProfile>())
        let records = try context.fetch(FetchDescriptor<ToothRecord>())
        var changed = false

        let orphanChildIDs = Set(records.map(\.childID)).subtracting(profiles.map(\.childID))
        if profiles.isEmpty && orphanChildIDs.isEmpty {
            let profile = ChildProfile(name: defaultName, dateStorageVersion: 0)
            context.insert(profile)
            profiles.append(profile)
            changed = true
        }

        for childID in orphanChildIDs.sorted() {
            let profile = ChildProfile(
                childID: childID,
                name: generatedName(
                    for: childID,
                    position: profiles.count + 1,
                    defaultName: defaultName
                ),
                dateStorageVersion: 0
            )
            context.insert(profile)
            profiles.append(profile)
            changed = true
        }

        let sortedProfiles = profiles.sorted {
            if $0.childID == ChildProfile.primaryChildID { return true }
            if $1.childID == ChildProfile.primaryChildID { return false }
            return $0.childID < $1.childID
        }
        for (index, profile) in sortedProfiles.enumerated()
        where profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            profile.name = generatedName(
                for: profile.childID,
                position: index + 1,
                defaultName: defaultName
            )
            changed = true
        }

        if changed {
            try context.save()
        }
    }

    private static func generatedName(
        for childID: String,
        position: Int,
        defaultName: String
    ) -> String {
        childID == ChildProfile.primaryChildID ? defaultName : "\(defaultName) \(position)"
    }
}
