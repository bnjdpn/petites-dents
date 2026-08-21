import SwiftData
import XCTest
@testable import PetitesDents

@MainActor
final class LegacyEntitlementTests: XCTestCase {
    private var suiteName = ""
    private var defaults = UserDefaults.standard

    override func setUp() {
        super.setUp()
        suiteName = "petitesdents.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: ToothRecord.self, ChildProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    // MARK: - 1. A brand-new install is never legacy

    func testFreshInstallIsNotLegacyAfterEveryServiceHasStarted() throws {
        let container = try makeContainer()

        try AppBootstrap.start(container: container, userDefaults: defaults, arguments: [])

        XCTAssertFalse(LegacyEntitlement.isUnlocked(userDefaults: defaults))
        XCTAssertTrue(defaults.bool(forKey: LegacyEntitlement.Keys.migrationCompleted))
        // The bootstrap inserted the default profile and ran both migrations;
        // none of that may look like usage.
        let profiles = try container.mainContext.fetch(FetchDescriptor<ChildProfile>())
        XCTAssertEqual(profiles.count, 1)
        for key in LegacyEntitlement.usageSignalKeys {
            XCTAssertNil(defaults.object(forKey: key), "bootstrap wrote usage signal \(key)")
        }
    }

    func testScreenshotRunIsNotLegacyEvenThoughItSeedsDataAndSelection() throws {
        let container = try makeContainer()

        try AppBootstrap.start(
            container: container,
            userDefaults: defaults,
            arguments: ["--screenshots"]
        )

        XCTAssertFalse(LegacyEntitlement.isUnlocked(userDefaults: defaults))
        XCTAssertNotNil(defaults.string(forKey: "selectedChildID"))
        XCTAssertFalse(
            try container.mainContext.fetch(FetchDescriptor<ToothRecord>()).isEmpty,
            "the capture fixtures must have been seeded after the migration ran"
        )
    }

    func testUITestingRunNeverWritesToTheRealDefaults() throws {
        let container = try makeContainer()

        try AppBootstrap.start(
            container: container,
            userDefaults: defaults,
            arguments: ["--ui-testing"]
        )

        XCTAssertFalse(defaults.bool(forKey: LegacyEntitlement.Keys.migrationCompleted))
        XCTAssertFalse(LegacyEntitlement.isUnlocked(userDefaults: defaults))
    }

    /// Regression: a capture run used to write `selectedChildID` into the real
    /// defaults. The next ordinary launch on that device — a unit-test run
    /// hosted in the app, a rerun of the UI suite — then read it as a trace of
    /// earlier use and granted the Souvenirs unlock for free. The suite passed
    /// once on a fresh simulator and failed on every rerun; a TestFlight device
    /// used for captures would have been silently entitled.
    func testACaptureRunKeepsItsWritesOutOfTheRealDefaults() throws {
        let volatileDefaults = AppDefaults.make(["--ui-testing", "--screenshots"])
        addTeardownBlock {
            volatileDefaults.removePersistentDomain(forName: AppDefaults.suiteName)
        }
        XCTAssertNotEqual(volatileDefaults, UserDefaults.standard)

        // Compared, never asserted clean: the simulator this suite runs on may
        // already carry values from earlier runs. What must not happen is this
        // capture run adding or changing one.
        let signalsBefore = LegacyEntitlement.usageSignalKeys.reduce(into: [String: String?]()) { keys, key in
            keys[key] = UserDefaults.standard.object(forKey: key) as? String
        }

        let container = try makeContainer()
        try AppBootstrap.start(
            container: container,
            userDefaults: volatileDefaults,
            arguments: ["--ui-testing", "--screenshots"]
        )

        XCTAssertNotNil(volatileDefaults.string(forKey: "selectedChildID"))
        for (key, before) in signalsBefore {
            XCTAssertEqual(
                UserDefaults.standard.object(forKey: key) as? String,
                before,
                "a capture run leaked usage signal \(key) into the real defaults"
            )
        }
    }

    func testAnOrdinaryLaunchKeepsTheRealDefaults() {
        XCTAssertEqual(AppDefaults.make([]), UserDefaults.standard)
        XCTAssertEqual(AppDefaults.make(["--screenshots"]), UserDefaults.standard)
    }

    // MARK: - 2. An install that carries earlier usage is legacy

    func testInstallWithASavedToothIsLegacy() throws {
        let container = try makeContainer()
        container.mainContext.insert(ToothRecord(toothID: "tooth-71"))
        try container.mainContext.save()

        try AppBootstrap.start(container: container, userDefaults: defaults, arguments: [])

        XCTAssertTrue(LegacyEntitlement.isUnlocked(userDefaults: defaults))
    }

    func testInstallWithABirthDateIsLegacy() throws {
        let container = try makeContainer()
        container.mainContext.insert(ChildProfile(name: "Emma", birthDate: Date()))
        try container.mainContext.save()

        try AppBootstrap.start(container: container, userDefaults: defaults, arguments: [])

        XCTAssertTrue(LegacyEntitlement.isUnlocked(userDefaults: defaults))
    }

    func testInstallWithASecondChildIsLegacy() throws {
        let container = try makeContainer()
        container.mainContext.insert(ChildProfile(childID: "lina", name: "Lina"))
        try container.mainContext.save()

        try AppBootstrap.start(container: container, userDefaults: defaults, arguments: [])

        XCTAssertTrue(LegacyEntitlement.isUnlocked(userDefaults: defaults))
    }

    func testEachUsageDefaultsKeyOnItsOwnMarksTheInstallAsLegacy() throws {
        for key in LegacyEntitlement.usageSignalKeys {
            let suite = "petitesdents.tests.\(UUID().uuidString)"
            let scoped = UserDefaults(suiteName: suite)!
            defer { scoped.removePersistentDomain(forName: suite) }
            scoped.set("value", forKey: key)
            let container = try makeContainer()

            try AppBootstrap.start(container: container, userDefaults: scoped, arguments: [])

            XCTAssertTrue(
                LegacyEntitlement.isUnlocked(userDefaults: scoped),
                "signal \(key) did not grandfather the install"
            )
        }
    }

    // MARK: - 3. Idempotence

    func testMigrateIfNeededIsIdempotent() throws {
        let container = try makeContainer()
        container.mainContext.insert(ToothRecord(toothID: "tooth-71"))
        try container.mainContext.save()

        LegacyEntitlement.migrateIfNeeded(
            context: container.mainContext,
            userDefaults: defaults,
            arguments: []
        )
        let afterFirstRun = LegacyEntitlement.isUnlocked(userDefaults: defaults)

        for _ in 0..<5 {
            LegacyEntitlement.migrateIfNeeded(
                context: container.mainContext,
                userDefaults: defaults,
                arguments: []
            )
        }

        XCTAssertTrue(afterFirstRun)
        XCTAssertTrue(LegacyEntitlement.isUnlocked(userDefaults: defaults))
        XCTAssertTrue(defaults.bool(forKey: LegacyEntitlement.Keys.migrationCompleted))
    }

    func testASecondRunNeverGrantsAccessToAnInstallThatWasNotLegacy() throws {
        let container = try makeContainer()
        LegacyEntitlement.migrateIfNeeded(
            context: container.mainContext,
            userDefaults: defaults,
            arguments: []
        )
        XCTAssertFalse(LegacyEntitlement.isUnlocked(userDefaults: defaults))

        // Data created after the migration is normal use of the new version,
        // not evidence of an older one.
        container.mainContext.insert(ToothRecord(toothID: "tooth-71"))
        try container.mainContext.save()
        LegacyEntitlement.migrateIfNeeded(
            context: container.mainContext,
            userDefaults: defaults,
            arguments: []
        )

        XCTAssertFalse(LegacyEntitlement.isUnlocked(userDefaults: defaults))
    }

    // MARK: - 4. Access granted is never taken away

    func testGrantedAccessSurvivesEverythingBeingErased() throws {
        let container = try makeContainer()
        container.mainContext.insert(ToothRecord(toothID: "tooth-71"))
        try container.mainContext.save()
        LegacyEntitlement.migrateIfNeeded(
            context: container.mainContext,
            userDefaults: defaults,
            arguments: []
        )
        XCTAssertTrue(LegacyEntitlement.isUnlocked(userDefaults: defaults))

        try container.mainContext.delete(model: ToothRecord.self)
        try container.mainContext.delete(model: ChildProfile.self)
        try container.mainContext.save()
        for key in LegacyEntitlement.usageSignalKeys {
            defaults.removeObject(forKey: key)
        }
        for _ in 0..<3 {
            LegacyEntitlement.migrateIfNeeded(
                context: container.mainContext,
                userDefaults: defaults,
                arguments: []
            )
        }
        try AppBootstrap.start(container: container, userDefaults: defaults, arguments: [])

        XCTAssertTrue(LegacyEntitlement.isUnlocked(userDefaults: defaults))
        let store = StoreService(userDefaults: defaults, arguments: [])
        XCTAssertTrue(store.hasSouvenirs)
        XCTAssertTrue(store.canExportKeepsake)
        XCTAssertTrue(store.canTrackPermanentTeeth)
        XCTAssertTrue(store.canAddPhoto(existingPhotoCount: 42))
    }
}
