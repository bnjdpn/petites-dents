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
}
