import XCTest
@testable import DynamicNotch

final class NotchFlowLanguageTests: XCTestCase {
    @MainActor
    func testMigrationChangesRussianAndSystemOnlyOnce() throws {
        let suite = "NotchFlow.LanguageTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("ru", forKey: GeneralSettingsStorage.Keys.appLanguage)
        defaults.set("system", forKey: GeneralSettingsStorage.Keys.notchLanguage)
        ApplicationSettingsStore.migrateInitialForkLanguage(defaults: defaults)
        XCTAssertEqual(defaults.string(forKey: GeneralSettingsStorage.Keys.appLanguage), "vi")
        XCTAssertEqual(defaults.string(forKey: GeneralSettingsStorage.Keys.notchLanguage), "vi")
        defaults.set("en", forKey: GeneralSettingsStorage.Keys.appLanguage)
        ApplicationSettingsStore.migrateInitialForkLanguage(defaults: defaults)
        XCTAssertEqual(defaults.string(forKey: GeneralSettingsStorage.Keys.appLanguage), "en")
    }

    @MainActor
    func testMigrationPreservesOtherExplicitLanguage() throws {
        let suite = "NotchFlow.LanguageTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("fr", forKey: GeneralSettingsStorage.Keys.appLanguage)
        ApplicationSettingsStore.migrateInitialForkLanguage(defaults: defaults)
        XCTAssertEqual(defaults.string(forKey: GeneralSettingsStorage.Keys.appLanguage), "fr")
        XCTAssertEqual(defaults.string(forKey: GeneralSettingsStorage.Keys.notchLanguage), "vi")
    }

    func testVietnameseIsAvailableForNotchAndWelcome() {
        XCTAssertTrue(DynamicNotchLanguage.notchLanguages.contains(.vietnamese))
        XCTAssertEqual(DynamicNotchLanguage.vietnamese.effectiveNotchLanguage, .vietnamese)
        XCTAssertEqual(L10n.string("notchflow.welcome.start", language: .vietnamese), "Bắt đầu")
        XCTAssertEqual(L10n.string("notch.battery.charging", language: .vietnamese), "Đang sạc")
        XCTAssertEqual(L10n.string("notch.onboarding.openGitHub", language: .vietnamese), "Open GitHub")
    }
}
