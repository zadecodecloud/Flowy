import SwiftUI

/// Explains a permission before macOS asks for it: an animated preview of what the feature does,
/// what Flowy uses it for, what it never does, and where the system asks.
struct PermissionPrimerSheet: View {
    let kind: Kind
    let locale: Locale
    /// True when macOS will show its own prompt; false when the user flips a switch in System Settings.
    let usesSystemSettings: Bool
    let onContinue: () -> Void
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func t(_ vi: String, _ en: String) -> String { V2.text(locale, vi, en) }
    private var content: PermissionPrimerContent { .init(kind: kind, locale: locale) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PermissionDemoView(kind: kind, animated: !reduceMotion)
                .frame(height: 170)
                .accessibilityLabel(Text(verbatim: content.demoDescription))

            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: content.title).font(.system(size: 17, weight: .semibold))
                Text(verbatim: content.summary).font(.system(size: 13)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(content.unlocks, id: \.self) { line in
                    bullet("checkmark.circle.fill", V2.green, line)
                }
                bullet("lock.shield.fill", V2.blue, content.privacy)
            }

            stepCard

            HStack {
                Button(t("Để sau", "Not now"), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(usesSystemSettings ? t("Mở Cài đặt hệ thống", "Open System Settings") : t("Tiếp tục", "Continue"),
                       action: onContinue)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(V2.blue)
                    .accessibilityIdentifier("settings.permissions.primer.continue")
            }
        }
        .padding(22)
        .frame(width: 440)
    }

    private func bullet(_ symbol: String, _ color: Color, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol).foregroundStyle(color).font(.system(size: 12)).accessibilityHidden(true)
            Text(verbatim: text).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Static picture of the next step: the macOS prompt, or the System Settings switch to turn on.
    private var stepCard: some View {
        HStack(spacing: 12) {
            Group {
                if usesSystemSettings {
                    SystemSettingsSwitchPicture(paneName: content.settingsPane, animated: !reduceMotion)
                } else {
                    SystemPromptPicture(buttonTitle: content.allowButton)
                }
            }
            .frame(width: 150, height: 74)
            .accessibilityHidden(true)
            Text(verbatim: usesSystemSettings
                 ? t("Trong Cài đặt hệ thống › Quyền riêng tư & Bảo mật › \(content.settingsPane), bật Flowy.",
                     "In System Settings › Privacy & Security › \(content.settingsPane), turn on Flowy.")
                 : t("macOS sẽ hỏi tiếp. Chọn “\(content.allowButton)”.", "macOS asks next. Choose “\(content.allowButton)”."))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.primary.opacity(0.05)))
    }
}

// MARK: - Copy

struct PermissionPrimerContent {
    let title: String
    let summary: String
    let unlocks: [String]
    let privacy: String
    let demoDescription: String
    let settingsPane: String
    let allowButton: String

    init(kind: Kind, locale: Locale) {
        func t(_ vi: String, _ en: String) -> String { V2.text(locale, vi, en) }
        allowButton = t("Cho phép", "Allow")
        switch kind {
        case .accessibility:
            title = t("Trợ năng", "Accessibility")
            summary = t("Để Flowy thay bảng âm lượng và độ sáng mặc định của macOS bằng bảng trên notch.",
                        "Lets Flowy replace the macOS volume and brightness overlay with its own on the notch.")
            unlocks = [t("Bảng âm lượng và độ sáng trên notch", "Volume and brightness on the notch"),
                       t("Ẩn bảng mặc định của macOS khi bấm phím", "No more macOS overlay when you press the keys")]
            privacy = t("Flowy chỉ đọc phím âm lượng và độ sáng, không ghi lại nội dung bạn gõ.",
                        "Flowy only reacts to the volume and brightness keys; it never records what you type.")
            demoDescription = t("Bấm phím âm lượng, thanh âm lượng hiện trên notch.", "Pressing a volume key shows the volume bar on the notch.")
            settingsPane = t("Trợ năng", "Accessibility")
        case .bluetooth:
            title = "Bluetooth"
            summary = t("Để Flowy hiện pin tai nghe và phụ kiện khi chúng kết nối.",
                        "Lets Flowy show your headphones' and accessories' battery when they connect.")
            unlocks = [t("Pin AirPods và tai nghe trên notch", "AirPods and headphone battery on the notch"),
                       t("Thông báo khi phụ kiện kết nối", "A heads-up when an accessory connects")]
            privacy = t("Flowy chỉ đọc mức pin, không ghép nối hay điều khiển thiết bị.",
                        "Flowy only reads battery levels; it doesn't pair with or control devices.")
            demoDescription = t("Tai nghe kết nối, notch hiện mức pin.", "Headphones connect and the notch shows their battery.")
            settingsPane = "Bluetooth"
        case .camera:
            title = t("Camera", "Camera")
            summary = t("Để Flowy hiện gương soi nhanh trong notch.", "Lets Flowy show a quick mirror inside the notch.")
            unlocks = [t("Gương soi trong notch, chỉ khi bạn mở", "A mirror in the notch, only when you open it")]
            privacy = t("Hình ảnh chỉ hiện trên máy bạn, không chụp, không lưu, không gửi đi.",
                        "The picture stays on your Mac: nothing is captured, saved or sent.")
            demoDescription = t("Notch mở ra và hiện gương soi.", "The notch opens into a mirror.")
            settingsPane = "Camera"
        case .mediaControls:
            title = t("Điều khiển nhạc", "Media controls")
            summary = t("Để các nút phát, tạm dừng và chuyển bài trên notch điều khiển ứng dụng nhạc của bạn.",
                        "Lets the play, pause and skip buttons on the notch control your music app.")
            unlocks = [t("Phát, tạm dừng, chuyển bài ngay trên notch", "Play, pause and skip right on the notch")]
            privacy = t("Flowy chỉ gửi lệnh phát nhạc, không đọc thao tác khác của bạn.",
                        "Flowy only sends playback commands; it doesn't watch anything else you do.")
            demoDescription = t("Bấm nút phát trên notch, nhạc bắt đầu.", "Pressing play on the notch starts the music.")
            settingsPane = t("Trợ năng", "Accessibility")
        case .calendar:
            title = t("Lịch", "Calendar")
            summary = t("Để Flowy nhắc sự kiện sắp tới trên notch.", "Lets Flowy remind you of upcoming events on the notch.")
            unlocks = [t("Sự kiện sắp tới hiện trên notch", "Upcoming events on the notch"),
                       t("Nhắc trước giờ họp", "A heads-up before meetings")]
            privacy = t("Lịch chỉ được đọc trên máy, không gửi đi đâu.", "Your calendar is read on your Mac only and never sent anywhere.")
            demoDescription = t("Notch hiện thẻ sự kiện sắp tới.", "The notch shows an upcoming event card.")
            settingsPane = t("Lịch", "Calendars")
        case .fullDiskAccess:
            title = t("Toàn quyền truy cập ổ đĩa", "Full Disk Access")
            summary = t("Chỉ để Flowy hiện đúng biểu tượng chế độ Tập trung đang bật.",
                        "Only used so Flowy can show the right icon for your current Focus mode.")
            unlocks = [t("Biểu tượng Tập trung đúng trên notch", "The right Focus icon on the notch")]
            privacy = t("Flowy chỉ đọc cài đặt Tập trung, không mở tệp nào khác.",
                        "Flowy only reads the Focus setting; it doesn't open your other files.")
            demoDescription = t("Bật chế độ Ngủ, notch hiện biểu tượng mặt trăng.", "Turning on Sleep focus shows a moon on the notch.")
            settingsPane = t("Toàn quyền truy cập ổ đĩa", "Full Disk Access")
        case .automation:
            title = t("Tự động hóa", "Automation")
            summary = t("Để Flowy đặt cửa sổ xem trước ảnh chụp màn hình vào giữa màn hình.",
                        "Lets Flowy center the screenshot and recording preview window.")
            unlocks = [t("Xem trước ảnh chụp ở giữa màn hình", "Screenshot previews centered on screen")]
            privacy = t("Flowy chỉ di chuyển cửa sổ xem trước, không điều khiển ứng dụng khác.",
                        "Flowy only moves the preview window; it doesn't control your other apps.")
            demoDescription = t("Ảnh chụp màn hình trượt vào giữa màn hình.", "A screenshot preview slides to the center.")
            settingsPane = t("Tự động hóa", "Automation")
        }
    }
}

// MARK: - Animated demos

/// A tiny desktop with a notch that acts out the feature. With reduced motion it shows the end frame.
struct PermissionDemoView: View {
    let kind: Kind
    let animated: Bool
    @State private var active: Bool

    init(kind: Kind, animated: Bool) {
        self.kind = kind
        self.animated = animated
        _active = State(initialValue: !animated)
    }

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [Color(red: 0.16, green: 0.20, blue: 0.36), Color(red: 0.38, green: 0.25, blue: 0.45)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            notch
                .padding(.top, 0)
            trigger
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.1)))
        .task(id: animated) {
            guard animated else { active = true; return }
            while !Task.isCancelled {
                active = false
                try? await Task.sleep(for: .seconds(0.9))
                withAnimation(.spring(duration: 0.55, bounce: 0.25)) { active = true }
                try? await Task.sleep(for: .seconds(2.4))
                withAnimation(.easeInOut(duration: 0.35)) { active = false }
                try? await Task.sleep(for: .seconds(0.6))
            }
        }
    }

    private var expandedSize: CGSize {
        switch kind {
        case .camera: return CGSize(width: 170, height: 110)
        case .calendar, .mediaControls: return CGSize(width: 230, height: 62)
        default: return CGSize(width: 200, height: 40)
        }
    }

    private var notch: some View {
        let size = active ? expandedSize : CGSize(width: 96, height: 22)
        return ZStack {
            UnevenRoundedRectangle(bottomLeadingRadius: active ? 18 : 9, bottomTrailingRadius: active ? 18 : 9, style: .continuous)
                .fill(.black)
            if active {
                notchContent
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private var notchContent: some View {
        switch kind {
        case .accessibility:
            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.2.fill").font(.system(size: 11))
                Capsule().fill(.white.opacity(0.25)).frame(height: 5)
                    .overlay(alignment: .leading) { Capsule().fill(.white).frame(width: 70, height: 5) }
            }
            .foregroundStyle(.white).padding(.horizontal, 14)
        case .bluetooth:
            HStack {
                Image(systemName: "airpodspro").font(.system(size: 13))
                Spacer()
                Text(verbatim: "82%").font(.system(size: 11, weight: .semibold)).foregroundStyle(V2.green)
            }
            .foregroundStyle(.white).padding(.horizontal, 14)
        case .camera:
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.35), Color(white: 0.18)], startPoint: .top, endPoint: .bottom))
                .overlay(Image(systemName: "person.fill").font(.system(size: 40)).foregroundStyle(.white.opacity(0.55)))
                .padding(8).padding(.top, 14)
        case .mediaControls:
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 6).fill(LinearGradient(colors: [.pink, .orange], startPoint: .top, endPoint: .bottom))
                    .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "Blue Hour").font(.system(size: 11, weight: .semibold))
                    Text(verbatim: "Flowy Sessions").font(.system(size: 9)).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Image(systemName: "pause.fill").font(.system(size: 13))
            }
            .foregroundStyle(.white).padding(.horizontal, 12).padding(.top, 8)
        case .calendar:
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2).fill(V2.blue).frame(width: 4, height: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "Design review").font(.system(size: 11, weight: .semibold))
                    Text(verbatim: "10:30 · 15 min").font(.system(size: 9)).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Image(systemName: "calendar").font(.system(size: 13))
            }
            .foregroundStyle(.white).padding(.horizontal, 14).padding(.top, 8)
        case .fullDiskAccess:
            HStack {
                Image(systemName: "moon.fill").foregroundStyle(.indigo)
                Spacer()
                Text(verbatim: "Sleep").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
            }
            .font(.system(size: 13)).padding(.horizontal, 14)
        case .automation:
            Image(systemName: "camera.viewfinder").font(.system(size: 14)).foregroundStyle(.white)
        }
    }

    /// What the user does to trigger the feature, drawn under the notch.
    @ViewBuilder
    private var trigger: some View {
        switch kind {
        case .accessibility:
            keyCap("speaker.wave.3.fill", pressed: active)
        case .bluetooth:
            Image(systemName: "airpodspro").font(.system(size: 26)).foregroundStyle(.white)
                .opacity(active ? 1 : 0.35).scaleEffect(active ? 1 : 0.9)
        case .mediaControls:
            keyCap("playpause.fill", pressed: active)
        case .automation:
            RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.9))
                .overlay(Image(systemName: "photo").foregroundStyle(.gray))
                .frame(width: 70, height: 46)
                .offset(x: active ? 0 : 120, y: active ? -40 : 0)
        default:
            EmptyView()
        }
    }

    private func keyCap(_ symbol: String, pressed: Bool) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 14))
            .foregroundStyle(.white)
            .frame(width: 44, height: 34)
            .background(RoundedRectangle(cornerRadius: 7).fill(.white.opacity(pressed ? 0.28 : 0.14)))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.white.opacity(0.25)))
            .scaleEffect(pressed ? 0.92 : 1)
    }
}

// MARK: - Step pictures

/// Static sketch of the macOS permission alert, with the button to choose highlighted.
private struct SystemPromptPicture: View {
    let buttonTitle: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "app.badge.checkmark").font(.system(size: 16)).foregroundStyle(.secondary)
            RoundedRectangle(cornerRadius: 2).fill(.primary.opacity(0.2)).frame(width: 90, height: 5)
            RoundedRectangle(cornerRadius: 2).fill(.primary.opacity(0.12)).frame(width: 70, height: 4)
            HStack(spacing: 6) {
                Capsule().fill(.primary.opacity(0.12)).frame(width: 50, height: 14)
                Text(verbatim: buttonTitle).font(.system(size: 8, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 50, height: 14).background(Capsule().fill(V2.blue))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .windowBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.primary.opacity(0.12)))
    }
}

/// Sketch of a System Settings privacy list with Flowy's switch turning on.
private struct SystemSettingsSwitchPicture: View {
    let paneName: String
    let animated: Bool
    @State private var on = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(verbatim: paneName).font(.system(size: 8, weight: .semibold)).lineLimit(1)
            row(name: "Flowy", icon: true, isOn: on)
            row(name: nil, icon: false, isOn: true).opacity(0.4)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .windowBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.primary.opacity(0.12)))
        .task(id: animated) {
            guard animated else { on = true; return }
            while !Task.isCancelled {
                on = false
                try? await Task.sleep(for: .seconds(1.2))
                withAnimation(.snappy(duration: 0.3)) { on = true }
                try? await Task.sleep(for: .seconds(2.2))
            }
        }
    }

    private func row(name: String?, icon: Bool, isOn: Bool) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(icon ? Color.black : .primary.opacity(0.2)).frame(width: 12, height: 12)
                .overlay { if icon { Capsule().fill(.white).frame(width: 6, height: 3).rotationEffect(.degrees(-28)) } }
            if let name {
                Text(verbatim: name).font(.system(size: 8))
            } else {
                RoundedRectangle(cornerRadius: 2).fill(.primary.opacity(0.2)).frame(width: 40, height: 4)
            }
            Spacer()
            Capsule().fill(isOn ? V2.blue : .primary.opacity(0.2)).frame(width: 20, height: 11)
                .overlay(alignment: isOn ? .trailing : .leading) { Circle().fill(.white).frame(width: 9).padding(1) }
        }
    }
}
