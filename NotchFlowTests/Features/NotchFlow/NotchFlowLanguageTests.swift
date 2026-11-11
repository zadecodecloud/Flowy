import XCTest
@testable import NotchFlow

final class NotchFlowLanguageTests: XCTestCase {
    func testFreshInstallDefaultsToEnglish() {
        XCTAssertEqual(GeneralSettingsStorage.defaultValues[GeneralSettingsStorage.Keys.appLanguage] as? String, NotchLanguage.english.rawValue)
        XCTAssertEqual(GeneralSettingsStorage.defaultValues[GeneralSettingsStorage.Keys.notchLanguage] as? String, NotchLanguage.english.rawValue)
    }

    func testVietnameseIsAvailableForNotchAndWelcome() {
        XCTAssertTrue(NotchLanguage.notchLanguages.contains(.vietnamese))
        XCTAssertEqual(NotchLanguage.vietnamese.effectiveNotchLanguage, .vietnamese)
        XCTAssertEqual(NotchLanguage.notchLanguages, [.english, .vietnamese])
        XCTAssertEqual(L10n.string("notchflow.welcome.start", language: .vietnamese), "Bắt đầu")
        XCTAssertEqual(L10n.string("notch.battery.charging", language: .vietnamese), "Đang sạc")
        XCTAssertEqual(L10n.string("notch.onboarding.openGitHub", language: .vietnamese), "Open GitHub")
    }
}
