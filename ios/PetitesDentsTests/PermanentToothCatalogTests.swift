import XCTest
@testable import PetitesDents

final class PermanentToothCatalogTests: XCTestCase {
    func testTwentyFourPermanentTeethTwelvePerArch() {
        XCTAssertEqual(PermanentToothCatalog.all.count, 24)
        XCTAssertEqual(PermanentToothCatalog.upper.count, 12)
        XCTAssertEqual(PermanentToothCatalog.lower.count, 12)
        XCTAssertEqual(
            PermanentToothCatalog.upper.count,
            DentalArchGeometry.permanentSlots
        )
    }

    func testEveryPermanentToothIsMarkedAsSuchAndHasAUniqueIdentifier() {
        XCTAssertTrue(PermanentToothCatalog.all.allSatisfy { $0.phase == .permanent })
        XCTAssertEqual(Set(PermanentToothCatalog.all.map(\.id)).count, 24)
        XCTAssertEqual(Set(PermanentToothCatalog.all.map(\.fdi)).count, 24)
    }

    func testPermanentAndPrimaryIdentifiersNeverCollide() {
        let primary = Set(ToothCatalog.all.map(\.id))
        let permanent = Set(PermanentToothCatalog.all.map(\.id))
        XCTAssertTrue(primary.isDisjoint(with: permanent))
    }

    func testSuccessorMappingIsBijectiveOverTheTwentyBabyTeeth() {
        let predecessors = PermanentToothCatalog.all.compactMap(\.predecessorFDI)
        XCTAssertEqual(predecessors.count, 20)
        XCTAssertEqual(Set(predecessors), Set(ToothCatalog.all.map(\.fdi)))
        for tooth in ToothCatalog.all {
            let successor = PermanentToothCatalog.successor(ofPrimaryFDI: tooth.fdi)
            XCTAssertNotNil(successor, "no successor for \(tooth.fdi)")
            XCTAssertEqual(successor?.arch, tooth.arch)
            XCTAssertEqual(successor?.side, tooth.side)
        }
    }

    func testTheFourSixYearMolarsAreTheOnlyTeethWithoutAPredecessor() {
        XCTAssertEqual(
            Set(PermanentToothCatalog.withoutPredecessor.map(\.fdi)),
            [16, 26, 36, 46]
        )
        XCTAssertTrue(
            PermanentToothCatalog.withoutPredecessor.allSatisfy { $0.kind == .firstMolar }
        )
    }

    func testSecondPermanentMolarsAndWisdomTeethAreOutOfScope() {
        let tracked = Set(PermanentToothCatalog.all.map(\.fdi))
        for fdi in [17, 27, 37, 47, 18, 28, 38, 48] {
            XCTAssertFalse(tracked.contains(fdi), "\(fdi) must not be tracked")
        }
    }

    func testArchOrderMirrorsTheBabyArchAnatomically() {
        XCTAssertEqual(
            PermanentToothCatalog.expectedFDIs(for: .upper),
            [26, 25, 24, 23, 22, 21, 11, 12, 13, 14, 15, 16]
        )
        XCTAssertEqual(
            PermanentToothCatalog.expectedFDIs(for: .lower),
            [36, 35, 34, 33, 32, 31, 41, 42, 43, 44, 45, 46]
        )
    }

    func testPermanentTeethAnnounceTheirTypicalAgeInYears() throws {
        let molar = try XCTUnwrap(PermanentToothCatalog.definition(forFDI: 46))
        XCTAssertEqual(molar.minMonths, 72)
        XCTAssertEqual(molar.maxMonths, 84)
    }
}
