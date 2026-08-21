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

    func testExportIdentifiesOnlyTheSelectedProfileAndUsesDistinctFilename() throws {
        let selectedRecord = ToothRecord(
            childID: "lina",
            toothID: "tooth-71",
            teethingDate: Date(),
            note: "Lina private note"
        )
        let otherRecord = ToothRecord(
            childID: "alice",
            toothID: "tooth-81",
            teethingDate: Date(),
            note: "Alice private note"
        )
        let selectedSnapshots = ToothCatalog.all.map {
            ToothSnapshot(
                definition: $0,
                record: $0.id == selectedRecord.toothID ? selectedRecord : nil
            )
        }

        let url = try TeethPDFExporter.create(
            snapshots: selectedSnapshots,
            profileName: "Lïna Rose"
        )
        let text = try XCTUnwrap(PDFDocument(url: url)?.string)

        XCTAssertTrue(text.contains("Lïna Rose"), text)
        XCTAssertTrue(text.contains("Lina private note"), text)
        XCTAssertFalse(text.contains(otherRecord.note), text)
        XCTAssertTrue(url.lastPathComponent.contains("lina-rose"), url.lastPathComponent)
    }
}

extension TeethPDFExporterTests {
    /// The commercial border of the whole offer: the free clinical sheet is a
    /// document of data for a healthcare professional and never carries an
    /// image. It is defended by the machine, not by discipline.
    func testTheFreeClinicalSheetNeverContainsAPhotoEvenWhenEveryToothHasOne() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("petites-dents-clinical-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        var records: [String: ToothRecord] = [:]
        for definition in ToothCatalog.all {
            let record = ToothRecord(
                toothID: definition.id,
                teethingDate: Date(),
                eruptedDate: Date(),
                note: "Photographed tooth"
            )
            record.photoIDs = [
                try ToothPhotoStore.store(
                    imageData: ToothPhotoStoreTests.sampleImageData(),
                    childID: ToothRecord.primaryChildID,
                    toothID: definition.id,
                    root: root
                )
            ]
            records[definition.id] = record
        }
        let snapshots = ToothCatalog.all.map {
            ToothSnapshot(definition: $0, record: records[$0.id])
        }

        let url = try TeethPDFExporter.create(
            snapshots: snapshots,
            birthDate: Date(),
            profileName: "Emma"
        )
        let raw = String(decoding: try Data(contentsOf: url), as: UTF8.self)

        XCTAssertFalse(raw.contains("/Image"), "the free sheet must never embed an image")
        XCTAssertFalse(raw.contains("/DCTDecode"), "the free sheet must never embed a JPEG")
    }
}
