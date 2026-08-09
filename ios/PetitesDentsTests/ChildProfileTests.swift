import SwiftData
import XCTest
@testable import PetitesDents

@MainActor
final class ChildProfileTests: XCTestCase {
    func testBirthDatePersistsAndUpdatesInSwiftData() throws {
        let container = try ModelContainer(
            for: ChildProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let firstDate = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2025, month: 10, day: 2))
        )
        let updatedDate = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2025, month: 10, day: 3))
        )
        let profile = ChildProfile(birthDate: firstDate, calendar: calendar)

        context.insert(profile)
        try context.save()
        let fetched = try XCTUnwrap(context.fetch(FetchDescriptor<ChildProfile>()).first)
        XCTAssertEqual(fetched.birthDate, firstDate)

        fetched.setBirthDate(updatedDate, calendar: calendar)
        try context.save()
        XCTAssertEqual(
            try XCTUnwrap(context.fetch(FetchDescriptor<ChildProfile>()).first).birthDate,
            updatedDate
        )
    }

    func testLegacyLocalMidnightDatesMigrateOnceToStableCivilDates() throws {
        let container = try ModelContainer(
            for: ToothRecord.self, ChildProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        var paris = Calendar(identifier: .gregorian)
        paris.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Paris"))
        let legacyEruption = try XCTUnwrap(
            paris.date(from: DateComponents(year: 2026, month: 7, day: 18))
        )
        var honolulu = Calendar(identifier: .gregorian)
        honolulu.timeZone = try XCTUnwrap(TimeZone(identifier: "Pacific/Honolulu"))
        let legacyHonoluluEruption = try XCTUnwrap(
            honolulu.date(from: DateComponents(year: 2026, month: 7, day: 18))
        )
        let record = ToothRecord(toothID: "tooth-71")
        record.eruptedDate = legacyEruption
        let honoluluRecord = ToothRecord(toothID: "tooth-81")
        honoluluRecord.eruptedDate = legacyHonoluluEruption
        context.insert(record)
        context.insert(honoluluRecord)
        try context.save()

        try DateStorageMigration.migrateIfNeeded(in: context)

        let expected = CivilDate.normalized(legacyEruption, sourceCalendar: paris)
        XCTAssertEqual(record.eruptedDate, expected)
        XCTAssertEqual(honoluluRecord.eruptedDate, expected)
        let profile = try XCTUnwrap(context.fetch(FetchDescriptor<ChildProfile>()).first)
        XCTAssertEqual(profile.dateStorageVersion, DateStorageMigration.currentVersion)

        try DateStorageMigration.migrateIfNeeded(in: context)
        XCTAssertEqual(record.eruptedDate, expected)
    }

    func testLegacyPrimaryProfileAndRecordsMigrateWithoutDataLossAndRemainIdempotent() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let profile = ChildProfile(name: "", dateStorageVersion: 1)
        let record = ToothRecord(
            toothID: "tooth-71",
            teethingDate: Date(timeIntervalSince1970: 1_700_000_000),
            note: "legacy note"
        )
        let originalDate = record.teethingDate
        context.insert(profile)
        context.insert(record)
        try context.save()

        try ChildProfileMigration.migrateIfNeeded(in: context, defaultName: "Baby")
        try ChildProfileMigration.migrateIfNeeded(in: context, defaultName: "Changed default")

        let profiles = try context.fetch(FetchDescriptor<ChildProfile>())
        let records = try context.fetch(FetchDescriptor<ToothRecord>())
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles.first?.childID, ChildProfile.primaryChildID)
        XCTAssertEqual(profiles.first?.name, "Baby")
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.childID, ChildProfile.primaryChildID)
        XCTAssertEqual(records.first?.note, "legacy note")
        XCTAssertEqual(records.first?.teethingDate, originalDate)
    }

    func testMigrationPreservesASecondaryOnlyStoreAfterPrimaryWasDeleted() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(ChildProfile(childID: "twin-b", name: "Lina"))
        context.insert(ToothRecord(childID: "twin-b", toothID: "tooth-71", note: "Lina only"))
        try context.save()

        try ChildProfileMigration.migrateIfNeeded(in: context, defaultName: "Baby")

        let profiles = try context.fetch(FetchDescriptor<ChildProfile>())
        XCTAssertEqual(profiles.map(\.childID), ["twin-b"])
        XCTAssertEqual(profiles.first?.name, "Lina")
    }

    func testDateMigrationRunsForEveryChildAndOnlyOnce() throws {
        let container = try makeContainer()
        let context = container.mainContext
        var paris = Calendar(identifier: .gregorian)
        paris.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Paris"))
        let legacyDate = try XCTUnwrap(
            paris.date(from: DateComponents(year: 2026, month: 3, day: 29))
        )
        let primary = ChildProfile(name: "Alice", dateStorageVersion: 0)
        primary.birthDate = legacyDate
        let twin = ChildProfile(childID: "twin", name: "Lina", dateStorageVersion: 0)
        let primaryRecord = ToothRecord(toothID: "tooth-71")
        primaryRecord.teethingDate = legacyDate
        let twinRecord = ToothRecord(childID: "twin", toothID: "tooth-71")
        twinRecord.eruptedDate = legacyDate
        [primary, twin].forEach(context.insert)
        [primaryRecord, twinRecord].forEach(context.insert)
        try context.save()

        try DateStorageMigration.migrateIfNeeded(in: context)
        let expected = CivilDate.normalized(legacyDate, sourceCalendar: paris)
        XCTAssertEqual(primary.birthDate, expected)
        XCTAssertEqual(primaryRecord.teethingDate, expected)
        XCTAssertEqual(twinRecord.eruptedDate, expected)
        XCTAssertEqual(primary.dateStorageVersion, DateStorageMigration.currentVersion)
        XCTAssertEqual(twin.dateStorageVersion, DateStorageMigration.currentVersion)

        try DateStorageMigration.migrateIfNeeded(in: context)
        XCTAssertEqual(twinRecord.eruptedDate, expected)
    }

    func testRecordsAndDeletionStayIsolatedByChildID() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let primary = ChildProfile(name: "Alice")
        let twin = ChildProfile(childID: "twin", name: "Lina")
        let primaryRecord = ToothRecord(toothID: "tooth-71", note: "Alice note")
        let twinRecord = ToothRecord(childID: "twin", toothID: "tooth-71", note: "Lina note")
        [primary, twin].forEach(context.insert)
        [primaryRecord, twinRecord].forEach(context.insert)
        try context.save()

        XCTAssertNotEqual(primaryRecord.recordKey, twinRecord.recordKey)
        let fallback = try ChildProfileStore.delete(childID: "twin", in: context)

        XCTAssertEqual(fallback, ChildProfile.primaryChildID)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ChildProfile>()).map(\.name), ["Alice"])
        let remainingRecords = try context.fetch(FetchDescriptor<ToothRecord>())
        XCTAssertEqual(remainingRecords.count, 1)
        XCTAssertEqual(remainingRecords.first?.note, "Alice note")
        XCTAssertThrowsError(try ChildProfileStore.delete(childID: fallback, in: context)) {
            XCTAssertEqual($0 as? ChildProfileError, .cannotDeleteLastProfile)
        }
    }

    func testBirthAndEventDateValidationUseOnlyTheSelectedChild() throws {
        let container = try makeContainer()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let aliceBirth = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)))
        let linaBirth = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 6, day: 1)))
        let mayEvent = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 5, day: 1)))
        let julyEvent = try XCTUnwrap(calendar.date(from: DateComponents(year: 2025, month: 7, day: 1)))
        let alice = ChildProfile(name: "Alice", birthDate: aliceBirth, calendar: calendar)
        let lina = ChildProfile(childID: "twin", name: "Lina", birthDate: linaBirth, calendar: calendar)
        let linaRecord = ToothRecord(
            childID: "twin",
            toothID: "tooth-71",
            eruptedDate: julyEvent,
            calendar: calendar
        )
        [alice, lina].forEach(context.insert)
        context.insert(linaRecord)
        try context.save()

        XCTAssertNoThrow(try ChildProfileStore.validateEventDate(mayEvent, for: alice))
        XCTAssertThrowsError(try ChildProfileStore.validateEventDate(mayEvent, for: lina)) {
            XCTAssertEqual($0 as? ChildProfileError, .eventBeforeBirthDate)
        }
        XCTAssertNoThrow(
            try ChildProfileStore.setBirthDate(
                julyEvent,
                for: alice,
                records: [linaRecord],
                in: context
            )
        )
        XCTAssertThrowsError(
            try ChildProfileStore.setBirthDate(
                julyEvent.addingTimeInterval(86_400),
                for: lina,
                records: [linaRecord],
                in: context
            )
        ) {
            XCTAssertEqual($0 as? ChildProfileError, .birthDateAfterRecordedEvent)
        }
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: ToothRecord.self, ChildProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
