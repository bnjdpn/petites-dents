import XCTest
@testable import PetitesDents

final class ToothCatalogTests: XCTestCase {
    func testCatalogContainsTwentyUniqueTeethInAnatomicalOrder() {
        XCTAssertEqual(ToothCatalog.all.count, 20)
        XCTAssertEqual(Set(ToothCatalog.all.map(\.id)).count, 20)
        XCTAssertEqual(ToothCatalog.upper.map(\.fdi), [65, 64, 63, 62, 61, 51, 52, 53, 54, 55])
        XCTAssertEqual(ToothCatalog.lower.map(\.fdi), [75, 74, 73, 72, 71, 81, 82, 83, 84, 85])
    }

    func testSpecificationAgeRangesArePreserved() throws {
        let lowerCentral = try XCTUnwrap(ToothCatalog.all.first { $0.fdi == 71 })
        let upperCentral = try XCTUnwrap(ToothCatalog.all.first { $0.fdi == 61 })
        let secondMolar = try XCTUnwrap(ToothCatalog.all.first { $0.fdi == 65 })

        XCTAssertEqual(lowerCentral.minMonths...lowerCentral.maxMonths, 6...10)
        XCTAssertEqual(upperCentral.minMonths...upperCentral.maxMonths, 8...12)
        XCTAssertEqual(secondMolar.minMonths...secondMolar.maxMonths, 25...33)
    }
}
