import XCTest
@testable import PetitesDents

final class DentalArchGeometryTests: XCTestCase {
    func testArchesContainTenMirroredPlacements() {
        let upper = DentalArchGeometry.placements(for: .upper)
        let lower = DentalArchGeometry.placements(for: .lower)

        XCTAssertEqual(upper.count, 10)
        XCTAssertEqual(lower.count, 10)
        for index in upper.indices {
            XCTAssertEqual(upper[index].xFraction, lower[index].xFraction, accuracy: 0.0001)
            XCTAssertEqual(upper[index].yFraction + lower[index].yFraction, 1, accuracy: 0.0001)
        }
    }

    func testUpperAndLowerFollowHorseshoeCurves() {
        let upper = DentalArchGeometry.placements(for: .upper)
        let lower = DentalArchGeometry.placements(for: .lower)

        XCTAssertGreaterThan(upper[0].yFraction, upper[4].yFraction)
        XCTAssertEqual(upper[4].yFraction, upper[5].yFraction, accuracy: 0.0001)
        XCTAssertLessThan(lower[0].yFraction, lower[4].yFraction)
        XCTAssertEqual(lower[4].yFraction, lower[5].yFraction, accuracy: 0.0001)
    }

    func testPlacementsAndRotationsAreSymmetric() {
        let upper = DentalArchGeometry.placements(for: .upper)
        let lower = DentalArchGeometry.placements(for: .lower)

        for index in upper.indices {
            let mirroredIndex = upper.index(before: upper.endIndex) - index
            XCTAssertEqual(
                upper[index].xFraction + upper[mirroredIndex].xFraction,
                1,
                accuracy: 0.0001
            )
            XCTAssertEqual(upper[index].yFraction, upper[mirroredIndex].yFraction, accuracy: 0.0001)
            XCTAssertEqual(
                upper[index].rotationDegrees + upper[mirroredIndex].rotationDegrees,
                360,
                accuracy: 0.0001
            )
            XCTAssertEqual(
                lower[index].rotationDegrees + lower[mirroredIndex].rotationDegrees,
                0,
                accuracy: 0.0001
            )
        }
    }

    func testHeightPreservesCurveRatioAcrossPhoneAndTabletWidths() {
        XCTAssertEqual(DentalArchGeometry.height(forWidth: 280), 164, accuracy: 0.0001)
        XCTAssertEqual(DentalArchGeometry.height(forWidth: 350), 182, accuracy: 0.0001)
        XCTAssertEqual(DentalArchGeometry.height(forWidth: 760), 395.2, accuracy: 0.0001)
        XCTAssertEqual(DentalArchGeometry.height(forWidth: 1_200), 624, accuracy: 0.0001)
    }

    func testFDIOrderMatchesAnatomicalCatalogOrder() {
        XCTAssertEqual(
            DentalArchGeometry.expectedFDIs(for: .upper),
            [65, 64, 63, 62, 61, 51, 52, 53, 54, 55]
        )
        XCTAssertEqual(
            DentalArchGeometry.expectedFDIs(for: .lower),
            [75, 74, 73, 72, 71, 81, 82, 83, 84, 85]
        )
    }

    func testOuterTargetsKeepAFullTouchInsetAtTheNarrowestWidth() {
        let placements = DentalArchGeometry.placements(for: .upper)
        XCTAssertGreaterThanOrEqual(placements[0].xFraction * 280, 22)
        XCTAssertGreaterThanOrEqual((1 - placements[9].xFraction) * 280, 22)
    }
}
