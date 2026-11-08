// NotchFlow modification: concise product information. License information remains in the source distribution.
import SwiftUI

struct AboutAppSettingsView: View {
    @Environment(\.locale) private var locale
    @ObservedObject var applicationSettings: ApplicationSettingsStore
    @ObservedObject private var licenses = LicenseStore.shared
    @State private var licenseInput = ""
    @State private var licenseMessage: String?
    let onRequestInternetAccess: () -> Bool

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        SettingsPageScrollView {
            SettingsCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("NotchFlow").font(.title2.weight(.semibold))
                    Text("\(locale.dn("notchflow.about.version", fallback: "Version")) \(version)")
                    Text(locale.dn("notchflow.about.description", fallback: "A personal macOS notch utility."))
                        .foregroundStyle(.secondary)
                    Text(locale.dn("notchflow.about.updates", fallback: "Updates not configured"))
                        .foregroundStyle(.secondary)
                }
            }

            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text(licenses.hasPro ? "NotchFlow Pro" : "NotchFlow Free").font(.headline)
                    Text(locale.language.languageCode?.identifier == "vi" ? "Pro bao gồm File Tray và nhạc trên màn hình khóa." : "Pro includes File Tray and lock screen music.")
                        .foregroundStyle(.secondary)
                    SecureField(locale.language.languageCode?.identifier == "vi" ? "Nhập key Pro hoặc developer" : "Enter Pro or developer key", text: $licenseInput)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("settings.license.key")
                    HStack {
                        Button(locale.language.languageCode?.identifier == "vi" ? "Kích hoạt" : "Activate") {
                            do {
                                let kind = try licenses.activate(licenseInput)
                                licenseInput = ""
                                if locale.language.languageCode?.identifier == "vi" {
                                    licenseMessage = kind == .pro ? "Đã kích hoạt Pro." : "Đã mở công cụ developer."
                                } else {
                                    licenseMessage = kind == .pro ? "Pro activated." : "Developer access activated."
                                }
                            } catch LicenseStore.ActivationError.notConfigured {
                                licenseMessage = locale.language.languageCode?.identifier == "vi" ? "Chưa cấu hình hệ thống cấp key." : "License activation is not configured yet."
                            } catch {
                                licenseMessage = locale.language.languageCode?.identifier == "vi" ? "Key không hợp lệ hoặc đã hết hạn." : "The key is invalid or expired."
                            }
                        }.disabled(licenseInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        if licenses.hasPro {
                            Button(locale.language.languageCode?.identifier == "vi" ? "Gỡ key Pro" : "Remove Pro key") { licenses.deactivate(.pro) }
                        }
                        if licenses.hasDeveloperAccess {
                            Button(locale.language.languageCode?.identifier == "vi" ? "Gỡ key developer" : "Remove developer key") { licenses.deactivate(.developer) }
                        }
                    }
                    if let licenseMessage { Text(licenseMessage).font(.caption).foregroundStyle(.secondary) }
                    if !licenses.isConfigured {
                        Text(locale.language.languageCode?.identifier == "vi" ? "Chưa cấu hình kích hoạt key." : "Key activation is not configured.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

        }
        .accessibilityIdentifier("settings.about.root")
    }
}
