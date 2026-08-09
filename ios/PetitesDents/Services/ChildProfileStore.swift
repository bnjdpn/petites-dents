import Foundation
import SwiftData

@MainActor
enum ChildProfileStore {
    @discardableResult
    static func create(name: String, in context: ModelContext) throws -> ChildProfile {
        let normalizedName = try validatedName(name)
        let profile = ChildProfile(
            childID: UUID().uuidString.lowercased(),
            name: normalizedName
        )
        context.insert(profile)
        try context.save()
        return profile
    }

    static func rename(
        childID: String,
        name: String,
        in context: ModelContext
    ) throws {
        guard let profile = try context.fetch(FetchDescriptor<ChildProfile>())
            .first(where: { $0.childID == childID }) else {
            throw ChildProfileError.profileNotFound
        }
        profile.name = try validatedName(name)
        try context.save()
    }

    @discardableResult
    static func delete(childID: String, in context: ModelContext) throws -> String {
        let profiles = try context.fetch(FetchDescriptor<ChildProfile>())
        guard profiles.count > 1 else {
            throw ChildProfileError.cannotDeleteLastProfile
        }
        guard let profile = profiles.first(where: { $0.childID == childID }) else {
            throw ChildProfileError.profileNotFound
        }

        let records = try context.fetch(FetchDescriptor<ToothRecord>())
        for record in records where record.childID == childID {
            context.delete(record)
        }
        context.delete(profile)
        try context.save()

        return profiles
            .filter { $0.childID != childID }
            .sorted(by: profileSort)
            .first?.childID ?? ChildProfile.primaryChildID
    }

    static func setBirthDate(
        _ date: Date?,
        for profile: ChildProfile,
        records: [ToothRecord],
        in context: ModelContext
    ) throws {
        let earliestRecordedDate = records
            .filter { $0.childID == profile.childID }
            .flatMap { [$0.teethingDate, $0.eruptedDate].compactMap { $0 } }
            .min()
        if let date,
           let earliestRecordedDate,
           CivilDate.normalized(date) > earliestRecordedDate {
            throw ChildProfileError.birthDateAfterRecordedEvent
        }
        profile.setBirthDate(date)
        try context.save()
    }

    static func validateEventDate(_ date: Date, for profile: ChildProfile?) throws {
        if let birthDate = profile?.birthDate,
           CivilDate.normalized(date) < birthDate {
            throw ChildProfileError.eventBeforeBirthDate
        }
    }

    private static func validatedName(_ name: String) throws -> String {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            throw ChildProfileError.nameRequired
        }
        return String(normalizedName.prefix(40))
    }

    private static func profileSort(_ lhs: ChildProfile, _ rhs: ChildProfile) -> Bool {
        if lhs.childID == ChildProfile.primaryChildID { return true }
        if rhs.childID == ChildProfile.primaryChildID { return false }
        let comparison = lhs.name.localizedStandardCompare(rhs.name)
        return comparison == .orderedSame ? lhs.childID < rhs.childID : comparison == .orderedAscending
    }
}
