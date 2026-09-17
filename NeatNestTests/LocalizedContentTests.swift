import XCTest
@testable import NeatNest

final class LocalizedContentTests: XCTestCase {
    func testResolvesRequestedLanguage() {
        let content = LocalizedContent(["it": "Latte", "en": "Milk"])

        XCTAssertEqual(content.resolved(for: Locale(identifier: "it_IT")), "Latte")
        XCTAssertEqual(content.resolved(for: Locale(identifier: "en_US")), "Milk")
    }

    func testFallsBackToSourceLanguage() {
        let content = LocalizedContent(["it": "Guanciale"])

        XCTAssertEqual(content.resolved(for: Locale(identifier: "fr_FR")), "Guanciale")
    }

    func testPrefersRegionalVariantWhenPresent() {
        let content = LocalizedContent(["en": "Courgette", "en-US": "Zucchini", "it": "Zucchina"])

        XCTAssertEqual(content.resolved(for: Locale(identifier: "en_US")), "Zucchini")
        XCTAssertEqual(content.resolved(for: Locale(identifier: "en_GB")), "Courgette")
    }

    func testDecodesLegacyPlainStrings() {
        // I documenti scritti prima dell'i18n hanno una stringa, non una mappa.
        let decoded = LocalizedContent.decode("Tonno all'olio")

        XCTAssertEqual(decoded?.resolved(for: Locale(identifier: "it_IT")), "Tonno all'olio")
        XCTAssertEqual(decoded?.resolved(for: Locale(identifier: "en_US")), "Tonno all'olio")
    }

    func testDecodesMaps() {
        let decoded = LocalizedContent.decode(["it": "Pane", "en": "Bread"])

        XCTAssertEqual(decoded?.resolved(for: Locale(identifier: "en_US")), "Bread")
    }

    func testRejectsEmptyValues() {
        XCTAssertNil(LocalizedContent.decode(""))
        XCTAssertNil(LocalizedContent.decode(["it": "   "]))
        XCTAssertNil(LocalizedContent.decode(nil))
    }

    func testSearchableCorpusCoversEveryLanguage() {
        // Cercare "milk" deve funzionare anche con l'app in italiano.
        let content = LocalizedContent(["it": "Latte", "en": "Milk"])

        XCTAssertTrue(content.searchableCorpus.contains("Milk"))
        XCTAssertTrue(content.searchableCorpus.contains("Latte"))
    }
}
