import SwiftUI

/// v2 License page: its own sidebar row with the verified seal.
struct SettingsLicenseView: View {
    @Environment(\.locale) private var locale
    @ObservedObject private var licenses = LicenseStore.shared
    @State private var licenseInput = ""
    @State private var licenseMessage: String?

    private var isVietnamese: Bool { locale.language.languageCode?.identifier == "vi" }
    private func t(_ vi: String, _ en: String) -> String { V2.text(locale, vi, en) }

    var body: some View {
        V2Page {
            V2Row {
                V2Tile {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: licenses.hasPro ? "checkmark.seal.fill" : "seal")
                            .font(.system(size: 30))
                            .foregroundStyle(licenses.hasPro ? Color(red: 0x1D / 255, green: 0x9B / 255, blue: 0xF0 / 255) : .secondary)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(licenses.hasPro ? "NotchFlow Pro" : "NotchFlow Free")
                                .font(.system(size: 17, weight: .semibold))
                            Text(isVietnamese ? "Pro bao gồm File Tray và nhạc trên màn hình khóa." : "Pro includes File Tray and lock screen music.")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        V2Pill(text: licenses.hasPro ? t("Đã kích hoạt", "Active") : t("Bản miễn phí", "Free"),
                               color: licenses.hasPro ? V2.green : V2.orange)
                    }
                    VStack(alignment: .leading, spacing: 10) {
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
                .v2Span(3)
            }

            V2Tile(title: t("Pro mở khóa", "Pro unlocks")) {
                V2ToggleFreeList(items: [
                    ("tray.full", t("Khay file", "File Tray"), t("Kéo thả file lên notch và giữ lại.", "Drop files on the notch and keep them.")),
                    ("music.note.list", t("Nhạc trên màn hình khóa", "Lock screen music"), t("Bảng nhạc, lời bài hát và giữ màn hình sáng.", "Music panel, lyrics and keep-awake."))
                ])
            }
        }
        .accessibilityIdentifier("settings.license.root")
    }
}

/// Read-only list of icon + title + note rows.
private struct V2ToggleFreeList: View {
    let items: [(String, String, String)]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 { Rectangle().fill(.primary.opacity(0.08)).frame(height: 1) }
                HStack(spacing: 12) {
                    Image(systemName: item.0).font(.system(size: 14)).foregroundStyle(V2.blue).frame(width: 20)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: item.1).font(.system(size: 13))
                        Text(verbatim: item.2).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
            }
        }
    }
}
