import XCTest
import AppKit
@testable import NotchFlow

/// NotchFlow ships English (default) and Vietnamese.
final class LocalizationCatalogTests: XCTestCase {
    private static let representativeKeys = [
        "menuBar.settings",
        "menuBar.quit",
        "common.cancel",
        "settings.section.lockScreen.title",
        "notchflow.mirror.title"
    ]

    private static let formattedKeys = [
        "menuBar.version",
        "settings.reset.title",
        "settings.search.empty.subtitle"
    ]

    func testEveryShippedLanguageHasAnLprojDirectory() {
        for language in NotchLanguage.allCases {
            XCTAssertNotNil(Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
                            "No .lproj directory is bundled for \(language.rawValue)")
        }
    }

    func testEveryShippedLanguageTranslatesRepresentativeKeys() {
        for language in NotchLanguage.allCases {
            for key in Self.representativeKeys {
                let value = L10n.string(key, language: language)
                XCTAssertNotEqual(value, key, "\(key) is unresolved in \(language.rawValue)")
                XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        XCTAssertEqual(L10n.string("menuBar.quit", language: .english), "Quit")
        XCTAssertNotEqual(L10n.string("menuBar.settings", language: .vietnamese),
                          L10n.string("menuBar.settings", language: .english))
    }

    func testTranslationsPreserveFormatSpecifiers() throws {
        for key in Self.formattedKeys {
            let english = try formatSpecifiers(in: L10n.string(key, language: .english))
            XCTAssertFalse(english.isEmpty, "\(key) was expected to carry format specifiers")
            XCTAssertEqual(try formatSpecifiers(in: L10n.string(key, language: .vietnamese)), english, key)
        }
    }

    func testMissingTranslationsFallBackToEnglishThenFallback() {
        XCTAssertEqual(L10n.string("notchflow.test.missing.key", language: .vietnamese, fallback: "Fallback"), "Fallback")
        XCTAssertEqual(L10n.string("notchflow.test.missing.key", language: .english), "notchflow.test.missing.key")
    }

    func testRetiredAndUnknownLanguagesResolveToEnglish() {
        for raw in [nil, "ru", "system", "de", "klingon", ""] as [String?] {
            XCTAssertEqual(NotchLanguage.resolved(raw), .english, "\(raw ?? "nil") must resolve to English")
        }
        XCTAssertEqual(NotchLanguage.resolved("vi"), .vietnamese)
        XCTAssertEqual(NotchLanguage(locale: Locale(identifier: "vi_VN")), .vietnamese)
        XCTAssertEqual(NotchLanguage(locale: Locale(identifier: "ru_RU")), .english)
    }

    func testLanguageStorageUsesNotchFlowKeys() {
        XCTAssertEqual(GeneralSettingsStorage.Keys.appLanguage, "notchflow.language.app")
        XCTAssertEqual(GeneralSettingsStorage.Keys.notchLanguage, "notchflow.language.notch")
    }

    func testEveryLanguageHasPresentationMetadataAndFlag() throws {
        for language in NotchLanguage.allCases {
            XCTAssertFalse(language.titleKeyString.isEmpty)
            XCTAssertFalse(language.nativeDisplayName.isEmpty)
            XCTAssertEqual(language.accentColors.count, 2)
            let asset = try XCTUnwrap(language.flagAssetName)
            XCTAssertNotNil(NSImage(named: asset), "Missing flag asset \(asset)")
        }
    }

    private func formatSpecifiers(in value: String) throws -> [String] {
        let pattern = "%(?:(\\d+)\\$)?[-+ #0]*[0-9]*(?:\\.[0-9]+)?(?:hh|h|ll|l|L|z|j|t|q)?([@diouxXeEfgGaAcsp%])"
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(value.startIndex..., in: value)
        return regex.matches(in: value, range: range).enumerated().compactMap { index, match -> String? in
            guard let conversion = Range(match.range(at: 2), in: value) else { return nil }
            let position: Int
            if let explicit = Range(match.range(at: 1), in: value), let parsed = Int(value[explicit]) {
                position = parsed
            } else {
                position = index + 1
            }
            return "\(position)\(value[conversion])"
        }.sorted()
    }
}
