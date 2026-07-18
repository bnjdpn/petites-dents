import XCTest

@MainActor
final class PetitesDentsUITests: XCTestCase {
    func testStoreScreenshots() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        let language = ProcessInfo.processInfo.environment["SCREENSHOT_LANGUAGE"] ?? "fr"
        let locale = ProcessInfo.processInfo.environment["SCREENSHOT_LOCALE"] ?? "fr_FR"
        app.launchArguments = [
            "--ui-testing",
            "--screenshots",
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale,
        ]
        app.launch()

        XCTAssertTrue(app.scrollViews["screen.mouth"].waitForExistence(timeout: 10))
        capture("01_Mouth")

        let centralTooth = app.buttons["tooth-61"]
        XCTAssertTrue(centralTooth.waitForExistence(timeout: 5))
        centralTooth.tap()
        XCTAssertTrue(app.datePickers["editor.date"].waitForExistence(timeout: 5))
        capture("02_ToothDetail")
        app.buttons["editor.close"].tap()

        tapTab(in: app, identifier: "tab.history", label: language.hasPrefix("fr") ? "Historique" : "History")
        XCTAssertTrue(app.scrollViews["screen.history"].waitForExistence(timeout: 5))
        capture("03_History")

        tapTab(in: app, identifier: "tab.more", label: language.hasPrefix("fr") ? "Plus" : "More")
        XCTAssertTrue(app.scrollViews["screen.more"].waitForExistence(timeout: 5))
        capture("04_ExportAndSupport")
    }

    private func tapTab(in app: XCUIApplication, identifier: String, label: String) {
        for elementType in [XCUIElement.ElementType.button, .cell, .other] {
            let identified = app.descendants(matching: elementType).matching(identifier: identifier).firstMatch
            if identified.exists {
                identified.tap()
                return
            }

            let labelled = app.descendants(matching: elementType)[label]
            if labelled.exists {
                labelled.tap()
                return
            }
        }

        XCTFail("Could not find tab \(identifier)")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
