import XCTest
@testable import PetitesDents

final class ToothRecordTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    func testRecordMovesThroughTheThreeStates() throws {
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 1)))
        let erupted = try XCTUnwrap(calendar.date(byAdding: .day, value: 3, to: start))
        let record = ToothRecord(toothID: "tooth-71")

        XCTAssertEqual(record.status, .ghost)
        record.markTeething(on: start, note: "  Red cheeks  ", calendar: calendar)
        XCTAssertEqual(record.status, .teething)
        XCTAssertEqual(record.note, "Red cheeks")

        try record.markErupted(on: erupted, note: record.note, calendar: calendar)
        XCTAssertEqual(record.status, .erupted)
    }

    func testEruptionCanBeRecordedWithoutAStartDate() throws {
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 8)))
        let record = ToothRecord(toothID: "tooth-51")

        try record.markErupted(on: date, note: "Already visible", calendar: calendar)

        XCTAssertNil(record.teethingDate)
        XCTAssertEqual(record.status, .erupted)
    }

    func testEruptionCannotPrecedeTeething() throws {
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 8)))
        let earlier = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: start))
        let record = ToothRecord(toothID: "tooth-61")
        record.markTeething(on: start, note: "", calendar: calendar)

        XCTAssertThrowsError(try record.markErupted(on: earlier, note: "", calendar: calendar)) {
            XCTAssertEqual($0 as? ToothRecordError, .eruptionBeforeTeething)
        }
    }
}

extension ToothRecordTests {
    func testABabyToothCanFallOutAfterItHasErupted() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let erupted = try XCTUnwrap(calendar.date(from: DateComponents(year: 2020, month: 7, day: 1)))
        let shed = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 4)))
        let record = ToothRecord(toothID: "tooth-71")

        try record.markErupted(on: erupted, note: "", calendar: calendar)
        try record.markShed(on: shed, note: "Wobbled a week", calendar: calendar)

        XCTAssertEqual(record.status, .shed)
        XCTAssertNotNil(record.sheddingDate)
        XCTAssertNotNil(record.eruptedDate)
    }

    func testAToothCannotFallOutBeforeItHasErupted() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let erupted = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 8)))
        let earlier = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: erupted))
        let record = ToothRecord(toothID: "tooth-61")
        try record.markErupted(on: erupted, note: "", calendar: calendar)

        XCTAssertThrowsError(try record.markShed(on: earlier, note: "", calendar: calendar)) {
            XCTAssertEqual($0 as? ToothRecordError, .sheddingBeforeEruption)
        }
    }

    func testResettingTheTeethingDateClearsAnyShedding() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let erupted = try XCTUnwrap(calendar.date(from: DateComponents(year: 2020, month: 7, day: 1)))
        let shed = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 4)))
        let record = ToothRecord(toothID: "tooth-71")
        try record.markErupted(on: erupted, note: "", calendar: calendar)
        try record.markShed(on: shed, note: "", calendar: calendar)

        record.markTeething(on: erupted, note: "", calendar: calendar)

        XCTAssertNil(record.sheddingDate)
        XCTAssertEqual(record.status, .teething)
    }

    func testASnapshotStillCountsAsEruptedOnceTheToothHasFallenOut() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let erupted = try XCTUnwrap(calendar.date(from: DateComponents(year: 2020, month: 7, day: 1)))
        let shed = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 4)))
        let record = ToothRecord(toothID: "tooth-71")
        try record.markErupted(on: erupted, note: "", calendar: calendar)
        try record.markShed(on: shed, note: "", calendar: calendar)
        let definition = try XCTUnwrap(ToothCatalog.definition(forFDI: 71))

        let snapshot = ToothSnapshot(definition: definition, record: record)

        XCTAssertTrue(snapshot.hasErupted)
        XCTAssertEqual(snapshot.status, .shed)
    }

    @MainActor
    func testTheMergedHistoryOrdersBothDentitionsMostRecentFirst() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let erupted = try XCTUnwrap(calendar.date(from: DateComponents(year: 2020, month: 7, day: 1)))
        let shed = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 4)))
        let permanent = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 4, day: 1)))

        let baby = ToothRecord(toothID: "tooth-71", calendar: calendar)
        try baby.markErupted(on: erupted, note: "", calendar: calendar)
        try baby.markShed(on: shed, note: "", calendar: calendar)
        let grown = ToothRecord(toothID: "tooth-31", calendar: calendar)
        try grown.markErupted(on: permanent, note: "", calendar: calendar)

        let entries = HistoryView.entries(
            primary: ToothCatalog.all.map {
                ToothSnapshot(definition: $0, record: $0.id == "tooth-71" ? baby : nil)
            },
            permanent: PermanentToothCatalog.all.map {
                ToothSnapshot(definition: $0, record: $0.id == "tooth-31" ? grown : nil)
            }
        )

        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries.map(\.kind), [.permanentErupted, .shed, .erupted])
    }
}
