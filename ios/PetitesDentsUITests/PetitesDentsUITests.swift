import XCTest

@MainActor
final class PetitesDentsUITests: XCTestCase {
    func testStoreScreenshots() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        let locale = Locale.current
        let language = locale.language.languageCode?.identifier ?? "en"
        let region = locale.region?.identifier ?? "US"
        app.launchArguments = [
            "--ui-testing",
            "--screenshots",
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", "\(language)_\(region)",
        ]
        app.launch()
        dismissAppleIntelligenceBannerIfNeeded()

        XCTAssertTrue(app.scrollViews["screen.mouth"].waitForExistence(timeout: 10))
        capture("01_Mouth")

        let centralTooth = app.buttons["tooth-61"]
        XCTAssertTrue(centralTooth.waitForExistence(timeout: 5))
        centralTooth.tap()
        XCTAssertTrue(app.datePickers["editor.date"].waitForExistence(timeout: 5))
        capture("02_ToothDetail")
        app.buttons["editor.close"].tap()

        tapTab(in: app, identifier: "tab.history", labels: ["History", "Historique"])
        XCTAssertTrue(app.scrollViews["screen.history"].waitForExistence(timeout: 5))
        capture("03_History")

        tapTab(in: app, identifier: "tab.more", labels: ["More", "Plus"])
        XCTAssertTrue(app.scrollViews["screen.more"].waitForExistence(timeout: 5))
        capture("04_ExportAndSupport")
    }

    private func tapTab(in app: XCUIApplication, identifier: String, labels: [String]) {
        for elementType in [XCUIElement.ElementType.button, .cell, .other] {
            let identified = app.descendants(matching: elementType).matching(identifier: identifier).firstMatch
            if identified.exists {
                identified.tap()
                return
            }

            for label in labels {
                let labelled = app.descendants(matching: elementType)[label]
                if labelled.exists {
                    labelled.tap()
                    return
                }
            }
        }

        XCTFail("Could not find tab \(identifier)")
    }

    private func dismissAppleIntelligenceBannerIfNeeded() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let banner = springboard.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Apple Intelligence"))
            .firstMatch
        guard banner.waitForExistence(timeout: 2) else { return }

        banner.swipeUp()
        XCTAssertFalse(banner.waitForExistence(timeout: 2), "System notification remained visible")
    }

    private func capture(_ name: String) {
        dismissAppleIntelligenceBannerIfNeeded()
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
