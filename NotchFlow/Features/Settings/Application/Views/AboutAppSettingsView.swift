// NotchFlow modification: concise product information. License information remains in the source distribution.
import SwiftUI

struct AboutAppSettingsView: View {
    @Environment(\.locale) private var locale
    @ObservedObject var applicationSettings: ApplicationSettingsStore
    let onRequestInternetAccess: () -> Bool

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var isVietnamese: Bool { locale.language.languageCode?.identifier == "vi" }
    private func t(_ vi: String, _ en: String) -> String { V2.text(locale, vi, en) }

    var body: some View {
        V2Page {
            V2Row(columns: 2) {
                V2Tile(title: t("Khởi động", "Startup")) {
                    V2ToggleList(items: [
                        .init(id: "launchAtLogin", label: t("Mở khi đăng nhập", "Open at login"),
                              isOn: $applicationSettings.isLaunchAtLoginEnabled),
                        .init(id: "menuBarIcon", label: t("Biểu tượng trên thanh menu", "Menu bar icon"),
                              note: applicationSettings.isMenuBarIconVisible ? nil
                                : t("Mở cài đặt bằng chuột phải lên notch.", "Open settings by right-clicking the notch."),
                              isOn: $applicationSettings.isMenuBarIconVisible),
                        .init(id: "dockIcon", label: t("Biểu tượng trên Dock", "Dock icon"),
                              isOn: $applicationSettings.isDockIconVisible)
                    ])
                }
                V2Tile(title: t("Giao diện & ngôn ngữ", "Appearance & language")) {
                    labeled(t("Chủ đề", "Theme")) {
                        V2Chips(options: Array(SettingsAppearanceMode.allCases),
                                selection: $applicationSettings.appearanceMode,
                                title: { Text($0.title) },
                                identifier: "settings.general.appearanceMode")
                    }
                    labeled(t("Cài đặt", "Settings")) {
                        V2Chips(options: NotchLanguage.allCases,
                                selection: $applicationSettings.appLanguage,
                                title: { Text(verbatim: $0.nativeDisplayName) },
                                identifier: "settings.v2.app.language")
                    }
                    labeled(t("Notch", "Notch")) {
                        V2Chips(options: NotchLanguage.notchLanguages,
                                selection: $applicationSettings.notchLanguage,
                                title: { Text(verbatim: $0.nativeDisplayName) },
                                identifier: "settings.v2.notch.language")
                    }
                }
            }

            V2Tile(title: t("Phiên bản", "Version")) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(verbatim: version)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                    Text(locale.nf("notchflow.about.updates", fallback: "Updates not configured"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                Text(locale.nf("notchflow.about.description", fallback: "A personal macOS notch utility."))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("settings.about.root")
    }

    private func labeled<C: View>(_ label: String, @ViewBuilder _ control: () -> C) -> some View {
        HStack(spacing: 10) {
            Text(verbatim: label).font(.system(size: 13)).frame(maxWidth: .infinity, alignment: .leading)
            control()
        }
        .padding(.vertical, 2)
    }
}
