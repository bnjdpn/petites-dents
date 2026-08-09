import Foundation
import XCTest

final class LocalizationParityTests: XCTestCase {
    func testEnglishBritishEnglishAndFrenchContainTheSameNonEmptyKeys() throws {
        let locales = ["en", "en-GB", "fr"]
        let dictionaries = try locales.map { locale in
            let url = try XCTUnwrap(
                Bundle.main.url(
                    forResource: "Localizable",
                    withExtension: "strings",
                    subdirectory: nil,
                    localization: locale
                ),
                "Missing bundled localisation for \(locale)"
            )
            let data = try Data(contentsOf: url)
            return try XCTUnwrap(
                PropertyListSerialization.propertyList(
                    from: data,
                    options: [],
                    format: nil
                ) as? [String: String],
                "Could not parse \(url.path)"
            )
        }

        let expectedKeys = Set(dictionaries[0].keys)
        for (index, dictionary) in dictionaries.enumerated() {
            XCTAssertEqual(Set(dictionary.keys), expectedKeys, "Key mismatch for \(locales[index])")
            XCTAssertTrue(
                dictionary.values.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
                "Empty localisation in \(locales[index])"
            )
        }
    }
}
