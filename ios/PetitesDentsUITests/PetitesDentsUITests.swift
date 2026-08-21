import StoreKitTest
import XCTest

@MainActor
final class PetitesDentsUITests: XCTestCase {

    /// `base_territory` of `fastlane/pro_products.json`. The base territory is
    /// the only storefront where the displayed price is the spec's `base_price`
    /// itself rather than an equalization of it, so it is the only storefront
    /// whose capture can be checked against the spec.
    static let baseTerritory = "FRA"
    /// The locale that formats the base-territory price. Pinned for the same
    /// reason: the string on the PNG has to be reproducible, not a function of
    /// whatever the capturing machine was left in.
    static let basePriceLocale = "fr_FR"

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
            "--store-bypass",
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

        tapTab(in: app, identifier: "tab.teeth", labels: ["Teeth", "Dents"])
        XCTAssertTrue(app.scrollViews["screen.mouth"].waitForExistence(timeout: 5))
        selectPermanentDentition(in: app)
        XCTAssertTrue(app.buttons["tooth-46"].waitForExistence(timeout: 5))
        capture("05_Definitives")
    }

    /// Produces the App Store Connect review screenshot of the in-app
    /// purchase. It is not part of the marketing matrix: the offer needs a
    /// StoreKit configuration or a sandbox account to show a real price, and
    /// the paywall never hardcodes one.
    ///
    /// App Review has to see what is being sold, so the capture is taken with
    /// the purchase block on screen — the buy button carrying
    /// `Product.displayPrice`, and Restore right under it. The exported PNG is
    /// the `iap_review_screenshot` of `release_config.json`; the extraction is
    /// done by `scripts/app_store/iap_review_screenshot.rb`.
    ///
    /// Two attachments leave this test: `Paywall`, the screen itself, and
    /// `PaywallPrice`, the exact price string that was on it. The second one
    /// is what makes the first one checkable by machine —
    /// `scripts/release_contract.rb` compares it to `fastlane/pro_products.json`
    /// and refuses a capture that shows a price the App Store does not have.
    func testPaywallScreenshot() throws {
        continueAfterFailure = false
        // `xcodebuild test` runs without the scheme's StoreKit configuration,
        // so the catalogue would be empty and the paywall would show its
        // "offer unavailable" state. SKTestSession loads the very same
        // PetitesDents.storekit, and the price still comes from StoreKit.
        let session = try SKTestSession(configurationFileNamed: "PetitesDents")
        session.disableDialogs = true
        session.clearTransactions()
        session.resetToDefaultState()
        // `base_territory` of `fastlane/pro_products.json`: the one storefront
        // where the displayed price is the spec's `base_price` itself and not
        // an equalization of it. Left to the simulator's own storefront, the
        // capture states whatever price that machine happened to be set to —
        // which is how a sibling app shipped "$29.99" to App Review while the
        // whole repository said 6,99 €.
        session.storefront = Self.baseTerritory
        session.locale = Locale(identifier: Self.basePriceLocale)
        defer { session.clearTransactions() }

        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--screenshots",
            "-paywall-screenshot",
        ]
        app.launch()
        dismissAppleIntelligenceBannerIfNeeded()

        let restore = app.buttons["paywall.restore"]
        XCTAssertTrue(restore.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["paywall.close"].exists)

        let buy = app.buttons["paywall.buy"]
        if !buy.waitForExistence(timeout: 30) {
            // A capture without the offer on it is a rejected in-app purchase
            // ("we were unable to locate the in-app purchase"). When the offer
            // never loads, say what was on screen instead of leaving a bare
            // boolean behind.
            capture("PaywallFailure")
            XCTFail(
                "The paywall never loaded the product: App Review would see no offer. "
                + "loading state on screen: \(app.descendants(matching: .any)["paywall.loading"].exists), "
                + "unavailable state on screen: \(app.descendants(matching: .any)["paywall.unavailable"].exists), "
                + "already-owned state on screen: \(app.descendants(matching: .any)["paywall.owned"].exists)"
            )
            return
        }
        // Scrolling all the way to the legal block puts the whole purchase card
        // — buy, price, Restore — above it, inside the frame.
        scrollUntilHittable(app.buttons["paywall.terms"], in: app)
        XCTAssertTrue(buy.isHittable, "The buy button never reached the visible area")
        XCTAssertTrue(restore.isHittable, "Restore must be visible on the review capture")

        // Every state the reviewer must not be shown. The purchase card renders
        // exactly one of them, so any of these on screen means the offer is not.
        for forbidden in ["paywall.loading", "paywall.unavailable", "paywall.owned", "paywall.message"] {
            XCTAssertFalse(
                app.descendants(matching: .any)[forbidden].exists,
                "The review capture must show the loaded offer, never \(forbidden)"
            )
        }

        let displayedPrice = app.staticTexts["paywall.price"].label
        XCTAssertFalse(
            displayedPrice.isEmpty,
            "The price must come from Product.displayPrice; without it the capture cannot be "
            + "checked against pro_products.json"
        )

        capture("Paywall")
        attach("PaywallPrice", string: displayedPrice)
    }

    private func scrollUntilHittable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        attempts: Int = 6
    ) {
        var remaining = attempts
        while !element.isHittable, remaining > 0 {
            app.swipeUp()
            remaining -= 1
        }
    }

    func testTheSecondDentitionIsBehindThePaywallWithoutTheUnlock() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        dismissAppleIntelligenceBannerIfNeeded()

        XCTAssertTrue(app.scrollViews["screen.mouth"].waitForExistence(timeout: 10))
        selectPermanentDentition(in: app)

        let unlock = app.buttons["mouth.unlock"]
        XCTAssertTrue(unlock.waitForExistence(timeout: 8))
        unlock.tap()
        XCTAssertTrue(app.buttons["paywall.restore"].waitForExistence(timeout: 15))
    }

    private func selectPermanentDentition(in app: XCUIApplication) {
        let picker = app.segmentedControls["mouth.phase"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.buttons.element(boundBy: 1).tap()
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

    /// Attaches a plain string next to the screenshots. Used for the price the
    /// paywall actually rendered: a PNG states a price in pixels, and nothing
    /// but a sidecar makes that price comparable to the spec by machine.
    private func attach(_ name: String, string: String) {
        let attachment = XCTAttachment(string: string)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func capture(_ name: String) {
        dismissAppleIntelligenceBannerIfNeeded()
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
