import Foundation
import XCTest
@testable import PetitesDents

/// Machine guard on the commercial contract of the single paid offer.
@MainActor
final class PaywallContractTests: XCTestCase {
    private static let locales = ["en", "en-GB", "fr"]

    private func strings(for locale: String) throws -> [String: String] {
        let url = try XCTUnwrap(
            Bundle.main.url(
                forResource: "Localizable",
                withExtension: "strings",
                subdirectory: nil,
                localization: locale
            ),
            "Missing bundled localisation for \(locale)"
        )
        return try XCTUnwrap(
            PropertyListSerialization.propertyList(
                from: try Data(contentsOf: url),
                options: [],
                format: nil
            ) as? [String: String]
        )
    }

    func testTheAppSellsExactlyOneNonConsumableAndHonoursItForEver() {
        XCTAssertEqual(SouvenirsCatalog.productID, "com.bnjdpn.petitesdents.souvenirs")
        XCTAssertEqual(SouvenirsCatalog.entitlementProductIDs, [SouvenirsCatalog.productID])
        XCTAssertEqual(SouvenirsCatalog.freePhotoLimitPerChild, 1)
    }

    func testTheVeryFirstPhotoIsFreeAndTheRestNeedsTheUnlock() {
        let suite = "petitesdents.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = StoreService(userDefaults: defaults, arguments: [])

        XCTAssertTrue(store.canAddPhoto(existingPhotoCount: 0))
        XCTAssertFalse(store.canAddPhoto(existingPhotoCount: 1))
        XCTAssertFalse(store.canAddPhoto(existingPhotoCount: 9))
        XCTAssertFalse(store.canExportKeepsake)
        XCTAssertFalse(store.canTrackPermanentTeeth)
    }

    func testTheStoreBypassNeedsBothFlagsAndNeverAppliesToThePaywallCapture() {
        func bypass(_ arguments: [String]) -> Bool {
            let suite = "petitesdents.tests.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            return StoreService(userDefaults: defaults, arguments: arguments).isStoreBypassEnabled
        }

        XCTAssertFalse(bypass([]))
        XCTAssertFalse(bypass(["--ui-testing"]))
        XCTAssertFalse(bypass(["--store-bypass"]))
        XCTAssertFalse(bypass(["--screenshots", "--store-bypass"]))
        XCTAssertTrue(bypass(["--ui-testing", "--store-bypass"]))
        XCTAssertTrue(bypass(["--ui-testing", "--screenshots", "--store-bypass"]))
        XCTAssertFalse(
            bypass(["--ui-testing", "--screenshots", "--store-bypass", "-paywall-screenshot"]),
            "the paywall capture must show the real, unpurchased state"
        )
    }

    func testThePaywallScreenshotArgumentIsRecognised() {
        XCTAssertTrue(LaunchEnvironment.shouldOpenPaywallAtLaunch(["-paywall-screenshot"]))
        XCTAssertTrue(LaunchEnvironment.shouldOpenPaywallAtLaunch(["--paywall-screenshot"]))
        XCTAssertFalse(LaunchEnvironment.shouldOpenPaywallAtLaunch(["--screenshots"]))
        XCTAssertFalse(LaunchEnvironment.shouldOpenPaywallAtLaunch([]))
    }

    func testEveryLocaleShipsTheRequiredPaywallDisclosures() throws {
        let required = [
            "paywall.title",
            "paywall.promise",
            "paywall.buy",
            "paywall.restore",
            "paywall.terms_summary",
            "paywall.terms",
            "paywall.privacy",
            "paywall.scope",
            "paywall.unavailable",
            "paywall.unavailable_body",
            "paywall.loading",
            "paywall.failed",
            "paywall.nothing_to_restore",
            "paywall.restored",
        ]
        for locale in Self.locales {
            let dictionary = try strings(for: locale)
            for key in required {
                let value = dictionary[key] ?? ""
                XCTAssertFalse(
                    value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    "\(locale) is missing \(key)"
                )
            }
        }
    }

    func testNoPaywallStringEverHardcodesAPrice() throws {
        let pricePattern = try NSRegularExpression(pattern: #"\d+[.,]\d{2}"#)
        for locale in Self.locales {
            for (key, value) in try strings(for: locale) where key.hasPrefix("paywall.") {
                let range = NSRange(value.startIndex..., in: value)
                XCTAssertNil(
                    pricePattern.firstMatch(in: value, range: range),
                    "\(locale)/\(key) hardcodes a price: \(value)"
                )
                for symbol in ["€", "$", "£", "¥"] {
                    XCTAssertFalse(
                        value.contains(symbol),
                        "\(locale)/\(key) hardcodes a currency: \(value)"
                    )
                }
            }
        }
    }

    func testTheTipJarIsGoneFromTheBinary() throws {
        for locale in Self.locales {
            let dictionary = try strings(for: locale)
            XCTAssertTrue(
                dictionary.keys.allSatisfy { !$0.hasPrefix("tips.") },
                "\(locale) still ships tip jar copy"
            )
            for value in dictionary.values {
                XCTAssertFalse(
                    value.lowercased().contains("unlocks no features"),
                    "a misleading tip sentence survived in \(locale)"
                )
                XCTAssertFalse(
                    value.lowercased().contains("ne débloque aucune fonctionnalité"),
                    "a misleading tip sentence survived in \(locale)"
                )
            }
        }
    }
}
