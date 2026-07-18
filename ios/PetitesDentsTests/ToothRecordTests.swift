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
