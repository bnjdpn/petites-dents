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

    func testEveryToothCenterSitsOnTheGumCenterline() {
        let expectedUpperY: [CGFloat] = [
            0.760,
            0.439536,
            0.324106,
            0.264567,
            0.238481,
            0.238481,
            0.264567,
            0.324106,
            0.439536,
            0.760,
        ]

        for (placement, expectedY) in zip(
            DentalArchGeometry.placements(for: .upper),
            expectedUpperY
        ) {
            XCTAssertEqual(placement.yFraction, expectedY, accuracy: 0.000001)
        }
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

    func testEachToothFamilyUsesItsOwnFixedOutline() {
        XCTAssertEqual(ToothKind.centralIncisor.familyOutline, .centralIncisor)
        XCTAssertEqual(ToothKind.lateralIncisor.familyOutline, .lateralIncisor)
        XCTAssertEqual(ToothKind.canine.familyOutline, .canine)
        XCTAssertEqual(ToothKind.firstMolar.familyOutline, .firstMolar)
        XCTAssertEqual(ToothKind.secondMolar.familyOutline, .secondMolar)
        XCTAssertEqual(Set(ToothKind.allCases.map(\.familyOutline)).count, 7)
    }
}

extension DentalArchGeometryTests {
    func testTheTwelveSlotArchKeepsTheBabyArchGeometryOfTheDefaultOne() {
        let primary = DentalArchGeometry.placements(for: .upper)
        let permanent = DentalArchGeometry.placements(
            for: .upper,
            slots: DentalArchGeometry.permanentSlots
        )

        XCTAssertEqual(primary.count, 10)
        XCTAssertEqual(permanent.count, 12)
        // Same outermost and innermost centres, so the two arches are concentric.
        XCTAssertEqual(permanent[0].xFraction, primary[0].xFraction, accuracy: 0.000001)
        XCTAssertEqual(permanent[11].xFraction, primary[9].xFraction, accuracy: 0.000001)
        XCTAssertEqual(permanent[5].xFraction, primary[4].xFraction, accuracy: 0.000001)
        XCTAssertEqual(permanent[6].xFraction, primary[5].xFraction, accuracy: 0.000001)
        XCTAssertEqual(permanent[0].yFraction, primary[0].yFraction, accuracy: 0.000001)
        XCTAssertEqual(permanent[5].yFraction, primary[4].yFraction, accuracy: 0.000001)
    }

    func testTheTwelveSlotArchStaysSymmetricAndMonotonic() {
        let upper = DentalArchGeometry.placements(
            for: .upper,
            slots: DentalArchGeometry.permanentSlots
        )
        let lower = DentalArchGeometry.placements(
            for: .lower,
            slots: DentalArchGeometry.permanentSlots
        )

        for index in upper.indices {
            let mirrored = upper.index(before: upper.endIndex) - index
            XCTAssertEqual(
                upper[index].xFraction + upper[mirrored].xFraction,
                1,
                accuracy: 0.0001
            )
            XCTAssertEqual(upper[index].yFraction, upper[mirrored].yFraction, accuracy: 0.0001)
            XCTAssertEqual(
                upper[index].rotationDegrees + upper[mirrored].rotationDegrees,
                360,
                accuracy: 0.0001
            )
            XCTAssertEqual(
                lower[index].rotationDegrees + lower[mirrored].rotationDegrees,
                0,
                accuracy: 0.0001
            )
            XCTAssertEqual(upper[index].yFraction + lower[index].yFraction, 1, accuracy: 0.0001)
        }
        for index in 0..<5 {
            XCTAssertGreaterThan(upper[index].xFraction, 0)
            XCTAssertLessThan(upper[index].xFraction, upper[index + 1].xFraction)
            XCTAssertGreaterThan(upper[index].yFraction, upper[index + 1].yFraction)
        }
    }

    func testTheOuterTouchInsetIsPreservedOnTheTwelveSlotArch() {
        let placements = DentalArchGeometry.placements(
            for: .upper,
            slots: DentalArchGeometry.permanentSlots
        )
        XCTAssertGreaterThanOrEqual(placements[0].xFraction * 280, 22)
        XCTAssertGreaterThanOrEqual((1 - placements[11].xFraction) * 280, 22)
    }

    func testSlotPitchShrinksExactlyWithTheNumberOfSlots() {
        XCTAssertEqual(DentalArchGeometry.slotPitch(slots: 10), 0.09, accuracy: 0.000001)
        XCTAssertEqual(DentalArchGeometry.slotPitch(slots: 12), 0.072, accuracy: 0.000001)
        XCTAssertEqual(
            DentalArchGeometry.layoutWidth(slots: 12, availableWidth: 320),
            400,
            accuracy: 0.001
        )
        XCTAssertEqual(
            DentalArchGeometry.layoutWidth(slots: 10, availableWidth: 320),
            320,
            accuracy: 0.001
        )
    }

    func testEveryToothFamilyKeepsItsOwnOutlineIncludingPremolars() {
        XCTAssertEqual(ToothKind.firstPremolar.familyOutline, .firstPremolar)
        XCTAssertEqual(ToothKind.secondPremolar.familyOutline, .secondPremolar)
        XCTAssertEqual(Set(ToothKind.allCases.map(\.familyOutline)).count, ToothKind.allCases.count)
    }
}
