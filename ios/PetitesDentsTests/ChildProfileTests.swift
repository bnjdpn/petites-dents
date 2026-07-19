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
}
