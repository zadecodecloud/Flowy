import SwiftUI
internal import AppKit

/// v2 License page: its own sidebar row with the verified seal.
struct SettingsLicenseView: View {
    @Environment(\.locale) private var locale
    @ObservedObject private var licenses = LicenseStore.shared
    @State private var licenseInput = ""
    @State private var licenseMessage: String?

    private func t(_ vi: String, _ en: String) -> String { V2.text(locale, vi, en) }

    private static let checkoutURL: URL? = (Bundle.main.object(forInfoDictionaryKey: "NotchFlowCheckoutURL") as? String)
        .flatMap { $0.hasPrefix("https://") ? URL(string: $0) : nil }
    private static let seal = Color(red: 0x1D / 255, green: 0x9B / 255, blue: 0xF0 / 255)

    var body: some View {
        V2Page {
            V2Tile {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: licenses.hasPaidPro ? "checkmark.seal.fill" : licenses.isTrialActive ? "clock.badge.checkmark" : "seal")
                        .font(.system(size: 30))
                        .foregroundStyle(licenses.hasPro ? Self.seal : .secondary)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: licenses.hasPaidPro ? "Flowy Pro" : licenses.isTrialActive ? "Flowy Pro · Trial" : "Flowy Free")
                            .font(.system(size: 17, weight: .semibold))
                        Text(verbatim: statusLine)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    V2Pill(text: pillText, color: licenses.hasPaidPro ? V2.green : licenses.isTrialActive ? V2.blue : V2.orange)
                }

                if !licenses.hasPaidPro {
                    HStack(spacing: 10) {
                        if let url = Self.checkoutURL {
                            Button { NSWorkspace.shared.open(url) } label: {
                                Label(t("Mua Pro trọn đời", "Buy Pro (lifetime)"), systemImage: "cart")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(V2.blue)
                            .accessibilityIdentifier("settings.license.buy")
                        }
                        if licenses.canStartTrial {
                            Button(t("Dùng thử Pro 14 ngày", "Try Pro for 14 days")) { licenses.startTrial() }
                                .accessibilityIdentifier("settings.license.trial")
                        }
                    }
                }
            }

            if licenses.certificate != nil || licenses.online != nil {
                V2Tile(title: t("Key trên máy này", "Key on this Mac")) {
                    if let claims = licenses.certificate?.claims {
                        labeled(t("Xác thực lần cuối", "Last verified"), claims.issuedAt.formatted(date: .abbreviated, time: .shortened))
                        labeled(t("Dùng offline đến", "Works offline until"),
                                claims.expiresAt.addingTimeInterval(LicenseStore.certificateOfflineGrace).formatted(date: .abbreviated, time: .omitted))
                    } else if let online = licenses.online {
                        labeled(t("Key", "Key"), Self.masked(online.key))
                        if let limit = online.activationLimit {
                            labeled(t("Số máy", "Macs"), "\(online.activationUsage ?? 1) / \(limit)")
                        }
                        labeled(t("Kiểm tra lần cuối", "Last checked"), online.lastValidated.formatted(date: .abbreviated, time: .shortened))
                    }
                    if let licenseMessage {
                        Text(verbatim: licenseMessage).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 10) {
                        Button(t("Kiểm tra lại", "Check again")) { Task { await licenses.revalidateIfNeeded(force: true) } }
                        Button(t("Gỡ khỏi máy này", "Deactivate this Mac"), role: .destructive) {
                            Task {
                                do {
                                    try await licenses.deactivateOnline()
                                    licenseMessage = nil
                                } catch {
                                    licenseMessage = t("Chưa gỡ được: không kết nối được máy chủ. Thử lại khi có mạng.",
                                                       "Couldn't deactivate: the server can't be reached. Try again when you're online.")
                                }
                            }
                        }
                        .accessibilityIdentifier("settings.license.deactivate")
                        if licenses.isWorking { ProgressView().controlSize(.small) }
                    }
                    .disabled(licenses.isWorking)
                }
            } else {
                V2Tile(title: t("Nhập key", "Enter key"),
                       hint: t("Mỗi key dùng được trên 2 máy Mac.", "Each key works on 2 Macs.")) {
                    HStack(spacing: 10) {
                        TextField(t("Dán key từ email mua hàng", "Paste the key from your receipt email"), text: $licenseInput)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(activate)
                            .accessibilityIdentifier("settings.license.key")
                        Button(t("Kích hoạt", "Activate"), action: activate)
                            .disabled(licenseInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || licenses.isWorking)
                        if licenses.isWorking { ProgressView().controlSize(.small) }
                    }
                    if let licenseMessage {
                        Text(verbatim: licenseMessage).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    if licenses.hasDeveloperAccess || licenses.hasPaidPro {
                        HStack(spacing: 10) {
                            if licenses.hasPaidPro {
                                Button(t("Gỡ key Pro", "Remove Pro key")) { licenses.deactivate(.pro) }
                            }
                            if licenses.hasDeveloperAccess {
                                Button(t("Gỡ key developer", "Remove developer key")) { licenses.deactivate(.developer) }
                            }
                        }
                    }
                }
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

    private var statusLine: String {
        switch licenses.state {
        case .revoked:
            return t("Key này đã bị thu hồi (hoàn tiền hoặc vô hiệu hóa). Cài đặt và dữ liệu của bạn vẫn được giữ.",
                     "This key was revoked (refund or disabled). Your settings and files are kept.")
        case .needsReverification:
            return t("Cần kết nối mạng để xác thực lại Pro. Cài đặt và dữ liệu của bạn vẫn được giữ.",
                     "Connect to the internet to verify Pro again. Your settings and files are kept.")
        case .proOffline:
            return t("Pro vẫn hoạt động. Chưa kết nối được máy chủ, sẽ thử lại tự động.",
                     "Pro is working. The license server couldn't be reached; it will retry automatically.")
        default: break
        }
        if licenses.hasPaidPro { return t("Cảm ơn bạn đã ủng hộ. Pro dùng trọn đời.", "Thanks for your support. Pro is yours for life.") }
        if licenses.isTrialActive {
            return t("Còn \(licenses.trialDaysLeft) ngày dùng thử File Tray và nhạc trên màn hình khóa.",
                     "\(licenses.trialDaysLeft) days left to try File Tray and lock screen music.")
        }
        if licenses.trialStart != nil { return t("Đã hết thời gian dùng thử.", "Your trial has ended.") }
        return t("Pro gồm File Tray và nhạc trên màn hình khóa.", "Pro includes File Tray and lock screen music.")
    }

    private var pillText: String {
        switch licenses.state {
        case .revoked: return t("Đã thu hồi", "Revoked")
        case .needsReverification: return t("Cần xác thực", "Verify again")
        case .proOffline: return t("Offline", "Offline")
        default: break
        }
        if licenses.hasPaidPro { return t("Đã kích hoạt", "Active") }
        if licenses.isTrialActive { return t("Còn \(licenses.trialDaysLeft) ngày", "\(licenses.trialDaysLeft) days left") }
        return t("Bản miễn phí", "Free")
    }

    private func activate() {
        let input = licenseInput
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        licenseMessage = nil
        if LicenseStore.isSignedToken(input) {
            do {
                let kind = try licenses.activate(input)
                licenseInput = ""
                licenseMessage = kind == .pro ? t("Đã kích hoạt Pro.", "Pro activated.") : t("Đã mở công cụ developer.", "Developer access activated.")
            } catch {
                licenseMessage = t("Key không hợp lệ hoặc đã hết hạn.", "The key is invalid or expired.")
            }
            return
        }
        Task {
            do {
                try await licenses.activateOnline(input)
                licenseInput = ""
                licenseMessage = t("Đã kích hoạt Pro.", "Pro activated.")
            } catch {
                licenseMessage = message(for: error)
            }
        }
    }

    private func message(for error: Error) -> String {
        switch error {
        case LicenseProviderError.limitReached, LicenseBackendError.limitReached:
            return t("Key đã dùng trên 2 máy. Gỡ key ở một máy khác rồi thử lại.",
                     "This key is already used on 2 Macs. Deactivate it on another Mac, then try again.")
        case LicenseProviderError.invalidKey, LicenseProviderError.wrongProduct,
             LicenseBackendError.invalidKey, LicenseBackendError.wrongProduct, LicenseBackendError.revoked:
            return t("Key không đúng. Kiểm tra lại key trong email mua hàng.", "That key isn't valid. Check the key in your receipt email.")
        case LicenseBackendError.rateLimited:
            return t("Thử quá nhiều lần. Đợi vài phút rồi thử lại.", "Too many attempts. Wait a few minutes, then try again.")
        case LicenseProviderError.network, LicenseBackendError.network:
            return t("Không kết nối được. Kiểm tra mạng rồi thử lại.", "Couldn't connect. Check your internet connection and try again.")
        case LicenseStore.ActivationError.notConfigured:
            return t("Chưa cấu hình kích hoạt key.", "Key activation isn't set up yet.")
        default:
            return t("Không kích hoạt được. Thử lại sau.", "Couldn't activate. Try again later.")
        }
    }

    private func labeled(_ label: String, _ value: String) -> some View {
        HStack {
            Text(verbatim: label).font(.system(size: 13))
            Spacer()
            Text(verbatim: value).font(.system(size: 13)).foregroundStyle(.secondary).textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }

    /// Shows only the last 4 characters of a key.
    static func masked(_ key: String) -> String {
        key.count > 4 ? "••••" + key.suffix(4) : key
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
