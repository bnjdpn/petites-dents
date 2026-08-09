import XCTest

@MainActor
final class PetitesDentsUITests: XCTestCase {
    func testAllTeethAreExposedAndRepresentativeTargetsOpenTheEditor() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        dismissAppleIntelligenceBannerIfNeeded()

        XCTAssertTrue(app.scrollViews["screen.mouth"].waitForExistence(timeout: 10))
        let expectedFDIs = [65, 64, 63, 62, 61, 51, 52, 53, 54, 55,
                            75, 74, 73, 72, 71, 81, 82, 83, 84, 85]
        for fdi in expectedFDIs {
            XCTAssertTrue(app.buttons["tooth-\(fdi)"].exists, "Missing tooth \(fdi)")
        }

        for fdi in [65, 61, 55, 75, 71, 85] {
            let tooth = app.buttons["tooth-\(fdi)"]
            XCTAssertTrue(tooth.isHittable, "Tooth \(fdi) is not hittable")
            tooth.tap()
            XCTAssertTrue(app.datePickers["editor.date"].waitForExistence(timeout: 5))
            app.buttons["editor.close"].tap()
        }
    }

    func testStoreScreenshots() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--screenshots",
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

    func testProfilesKeepTwinToothProgressIsolatedInEnglish() throws {
        try verifyProfileIsolation(
            language: "en",
            locale: "en_US",
            defaultName: "Baby",
            emptyStatus: "Not started",
            teethingStatus: "Teething"
        )
    }

    func testProfilesKeepTwinToothProgressIsolatedInFrench() throws {
        try verifyProfileIsolation(
            language: "fr",
            locale: "fr_FR",
            defaultName: "Bébé",
            emptyStatus: "Pas commencée",
            teethingStatus: "En poussée"
        )
    }

    private func verifyProfileIsolation(
        language: String,
        locale: String,
        defaultName: String,
        emptyStatus: String,
        teethingStatus: String
    ) throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale,
        ]
        app.launch()
        dismissAppleIntelligenceBannerIfNeeded()

        let selector = app.buttons["profile.selector"]
        XCTAssertTrue(selector.waitForExistence(timeout: 10))
        XCTAssertTrue(selector.label.contains(defaultName), selector.label)
        XCTAssertTrue(selector.isHittable)
        selector.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["profile.sheet"].waitForExistence(timeout: 5)
        )
        let addButton = app.buttons["profile.add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["profile.rename"].exists)
        XCTAssertTrue(app.buttons["profile.delete"].exists)
        addButton.tap()

        let nameField = app.textFields["profile.name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Lina")
        app.buttons["profile.save"].tap()

        XCTAssertTrue(app.buttons["profile.done"].waitForExistence(timeout: 5))
        app.buttons["profile.done"].tap()
        XCTAssertTrue(selector.waitForExistence(timeout: 5))
        XCTAssertTrue(selector.label.contains("Lina"), selector.label)
        XCTAssertTrue(selector.label.contains("2"), selector.label)

        let tooth = app.buttons["tooth-71"]
        XCTAssertTrue(tooth.waitForExistence(timeout: 5))
        XCTAssertEqual(tooth.value as? String, emptyStatus)
        tooth.tap()
        XCTAssertTrue(app.datePickers["editor.date"].waitForExistence(timeout: 5))
        let markTeething = app.buttons["editor.mark_teething"]
        if !markTeething.waitForExistence(timeout: 2) {
            let editorForm = app.collectionViews.firstMatch
            XCTAssertTrue(editorForm.exists)
            editorForm.swipeUp()
            editorForm.swipeUp()
        }
        XCTAssertTrue(markTeething.waitForExistence(timeout: 5))
        XCTAssertTrue(markTeething.isHittable)
        markTeething.tap()
        XCTAssertTrue(tooth.waitForExistence(timeout: 5))
        XCTAssertEqual(tooth.value as? String, teethingStatus)

        selector.tap()
        let primaryRow = app.buttons["profile.row.primary"]
        XCTAssertTrue(primaryRow.waitForExistence(timeout: 5))
        primaryRow.tap()
        XCTAssertTrue(tooth.waitForExistence(timeout: 5))
        XCTAssertEqual(tooth.value as? String, emptyStatus)

        selector.tap()
        let linaRow = app.buttons.matching(
            NSPredicate(format: "label == %@", "Lina")
        ).firstMatch
        XCTAssertTrue(linaRow.waitForExistence(timeout: 5))
        linaRow.tap()
        XCTAssertTrue(tooth.waitForExistence(timeout: 5))
        XCTAssertEqual(tooth.value as? String, teethingStatus)
        capture("Profiles-\(language.uppercased())")
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
