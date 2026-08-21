import PDFKit
import UIKit
import XCTest
@testable import PetitesDents

@MainActor
final class KeepsakePDFRendererTests: XCTestCase {
    private var root = FileManager.default.temporaryDirectory
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("petites-dents-keepsake-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func birthDate() throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(year: 2019, month: 10, day: 2)))
    }

    private func makeDocument(withPhoto: Bool) throws -> KeepsakeDocument {
        let erupted = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2020, month: 7, day: 18))
        )
        let shed = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 4))
        )
        let permanentErupted = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 4, day: 1))
        )

        let babyRecord = ToothRecord(
            toothID: "tooth-71",
            teethingDate: erupted,
            eruptedDate: erupted,
            sheddingDate: shed,
            note: "Wobbled for a week",
            calendar: calendar
        )
        if withPhoto {
            let photoID = try ToothPhotoStore.store(
                imageData: ToothPhotoStoreTests.sampleImageData(),
                childID: ToothRecord.primaryChildID,
                toothID: "tooth-71",
                root: root
            )
            babyRecord.photoIDs = [photoID]
        }
        let permanentRecord = ToothRecord(
            toothID: "tooth-41",
            eruptedDate: permanentErupted,
            calendar: calendar
        )

        let primary = ToothCatalog.all.map {
            ToothSnapshot(definition: $0, record: $0.id == "tooth-71" ? babyRecord : nil)
        }
        let permanent = PermanentToothCatalog.all.map {
            ToothSnapshot(definition: $0, record: $0.id == "tooth-41" ? permanentRecord : nil)
        }
        return KeepsakeDocumentBuilder.make(
            profileName: "Lïna Rose",
            birthDate: try birthDate(),
            childID: ToothRecord.primaryChildID,
            primary: primary,
            permanent: permanent,
            photoRoot: root
        )
    }

    func testTheKeepsakeCarriesTheChildTheDatesAndTheExactAge() throws {
        let document = try makeDocument(withPhoto: false)

        let url = try KeepsakePDFRenderer.render(document)
        let pdf = try XCTUnwrap(PDFDocument(url: url))
        let text = try XCTUnwrap(pdf.string)

        XCTAssertTrue(text.contains("Lïna Rose"), text)
        XCTAssertGreaterThanOrEqual(pdf.pageCount, 2)
        // Age in months AND days, both languages of the test runner.
        XCTAssertTrue(
            text.contains("9 months and 16 days") || text.contains("9 mois et 16 jours"),
            text
        )
        XCTAssertEqual(document.events.count, 3)
        XCTAssertEqual(document.shedCount, 1)
        XCTAssertEqual(document.permanentCount, 1)
        XCTAssertTrue(url.lastPathComponent.contains("lina-rose"), url.lastPathComponent)
    }

    func testTheKeepsakeIsTheDocumentThatCarriesThePhotos() throws {
        let document = try makeDocument(withPhoto: true)
        XCTAssertEqual(document.photos.count, 1)

        let url = try KeepsakePDFRenderer.render(document)
        let data = try Data(contentsOf: url)
        let raw = String(decoding: data, as: UTF8.self)

        XCTAssertTrue(data.starts(with: Data("%PDF".utf8)))
        XCTAssertTrue(raw.contains("/Image"), "the keepsake must embed the photos")
    }

    func testAnEmptyKeepsakeIsRefusedRatherThanPrintedBlank() throws {
        let document = KeepsakeDocumentBuilder.make(
            profileName: "Emma",
            birthDate: try birthDate(),
            childID: ToothRecord.primaryChildID,
            primary: ToothCatalog.all.map { ToothSnapshot(definition: $0, record: nil) },
            permanent: PermanentToothCatalog.all.map { ToothSnapshot(definition: $0, record: nil) },
            photoRoot: root
        )

        XCTAssertThrowsError(try KeepsakePDFRenderer.render(document))
    }

    func testThePaywallPreviewIsRenderedFromTheRealPageAtA4Proportions() throws {
        let document = try makeDocument(withPhoto: true)

        let image = KeepsakePDFRenderer.plateImage(document, width: 620)

        XCTAssertEqual(image.size.width, 620, accuracy: 0.5)
        XCTAssertEqual(
            image.size.height,
            620 * KeepsakePDFRenderer.pageSize.height / KeepsakePDFRenderer.pageSize.width,
            accuracy: 0.5
        )
    }
}
