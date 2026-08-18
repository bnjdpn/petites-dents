import Foundation
import XCTest

@testable import PetitesDents

final class ReviewPromptTests: XCTestCase {
    private let suiteName = "ReviewPromptTests"
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testPolicyRequiresAtLeastTwoValueEvents() {
        XCTAssertFalse(
            ReviewPromptPolicy.shouldPrompt(
                valueEventCount: ReviewPromptPolicy.minimumValueEvents - 1,
                currentVersion: "1.0.8",
                lastPromptedVersion: nil,
                lastPromptDate: nil,
                now: .now
            )
        )
        XCTAssertTrue(
            ReviewPromptPolicy.shouldPrompt(
                valueEventCount: ReviewPromptPolicy.minimumValueEvents,
                currentVersion: "1.0.8",
                lastPromptedVersion: nil,
                lastPromptDate: nil,
                now: .now
            )
        )
    }

    func testPolicyAllowsAtMostOnePromptPerVersion() {
        XCTAssertFalse(
            ReviewPromptPolicy.shouldPrompt(
                valueEventCount: 20,
                currentVersion: "1.0.8",
                lastPromptedVersion: "1.0.8",
                lastPromptDate: .now.addingTimeInterval(-90 * 86_400),
                now: .now
            )
        )
    }

    func testPolicyEnforcesFourteenDaysBetweenPrompts() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let thirteenDaysAgo = now.addingTimeInterval(-13 * 86_400)
        let fifteenDaysAgo = now.addingTimeInterval(-15 * 86_400)

        XCTAssertFalse(
            ReviewPromptPolicy.shouldPrompt(
                valueEventCount: 20,
                currentVersion: "1.0.9",
                lastPromptedVersion: "1.0.8",
                lastPromptDate: thirteenDaysAgo,
                now: now
            )
        )
        XCTAssertTrue(
            ReviewPromptPolicy.shouldPrompt(
                valueEventCount: 20,
                currentVersion: "1.0.9",
                lastPromptedVersion: "1.0.8",
                lastPromptDate: fifteenDaysAgo,
                now: now
            )
        )
    }

    func testTrackerPromptsOnceOnTheSecondEventAndRecordsThePrompt() {
        for _ in 1...(ReviewPromptPolicy.minimumValueEvents - 1) {
            XCTAssertFalse(
                ReviewPromptTracker.registerValueEvent(defaults: defaults, currentVersion: "1.0.8")
            )
        }
        XCTAssertTrue(
            ReviewPromptTracker.registerValueEvent(defaults: defaults, currentVersion: "1.0.8")
        )
        XCTAssertEqual(
            defaults.string(forKey: ReviewPromptDefaultsKey.lastPromptedVersion),
            "1.0.8"
        )
        XCTAssertNotNil(defaults.object(forKey: ReviewPromptDefaultsKey.lastPromptDate) as? Date)

        // Same version never prompts twice, however many events follow.
        for _ in 1...10 {
            XCTAssertFalse(
                ReviewPromptTracker.registerValueEvent(defaults: defaults, currentVersion: "1.0.8")
            )
        }
    }

    func testTrackerPromptsAgainOnANewVersionAfterFourteenDays() {
        let firstPrompt = Date(timeIntervalSinceReferenceDate: 800_000_000)
        for _ in 1...ReviewPromptPolicy.minimumValueEvents {
            _ = ReviewPromptTracker.registerValueEvent(
                defaults: defaults,
                currentVersion: "1.0.8",
                now: firstPrompt
            )
        }

        let tooSoon = firstPrompt.addingTimeInterval(10 * 86_400)
        XCTAssertFalse(
            ReviewPromptTracker.registerValueEvent(defaults: defaults, currentVersion: "1.0.9", now: tooSoon)
        )

        let farEnough = firstPrompt.addingTimeInterval(20 * 86_400)
        XCTAssertTrue(
            ReviewPromptTracker.registerValueEvent(defaults: defaults, currentVersion: "1.0.9", now: farEnough)
        )
    }
}
