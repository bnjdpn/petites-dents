import PDFKit
import XCTest
@testable import PetitesDents

@MainActor
final class TeethPDFExporterTests: XCTestCase {
    func testExportProducesANonEmptyPDFForTheCompleteCatalog() throws {
        let records = [
            "tooth-71": ToothRecord(toothID: "tooth-71", teethingDate: Date(), eruptedDate: Date(), note: "First tooth")
        ]
        let snapshots = ToothCatalog.all.map {
            ToothSnapshot(definition: $0, record: records[$0.id])
        }

        let url = try TeethPDFExporter.create(snapshots: snapshots)
        let data = try Data(contentsOf: url)

        XCTAssertTrue(data.starts(with: Data("%PDF".utf8)))
        XCTAssertGreaterThan(data.count, 1_000)
    }

    func testExportIncludesBirthDateAndCalendarAgeAtEruption() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let birthDate = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2025, month: 10, day: 2))
        )
        let eruptedDate = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 18))
        )
        let records = [
            "tooth-71": ToothRecord(
                toothID: "tooth-71",
                teethingDate: eruptedDate,
                eruptedDate: eruptedDate,
                note: "First tooth"
            )
        ]
        let snapshots = ToothCatalog.all.map {
            ToothSnapshot(definition: $0, record: records[$0.id])
        }

        let url = try TeethPDFExporter.create(
            snapshots: snapshots,
            birthDate: birthDate
        )
        let text = try XCTUnwrap(PDFDocument(url: url)?.string)

        XCTAssertTrue(
            text.contains("9 months and 16 days") || text.contains("9 mois et 16 jours"),
            text
        )
    }
}
