import SwiftUI

/// v2 "Thông báo" overview: headphone style, display time, and every alert type in one table
/// with a live on/off switch. Each row opens that alert's full page.
struct SettingsAlertsOverviewView: View {
    typealias Section = SettingsRootViewModel.Section

    @ObservedObject var connectivity: ConnectivitySettingsStore
    @ObservedObject var battery: BatterySettingsStore
    @ObservedObject var hud: HUDSettingsStore
    @ObservedObject var media: MediaAndFilesSettingsStore
    @ObservedObject var calendar: CalendarSettingsStore
    @ObservedObject var screenRecording: ScreenRecordingSettingsStore
    @ObservedObject var externalDevices: ExternalDevicesSettingsStore
    let sections: [Section]
    let title: (Section) -> String
    let onOpen: (Section) -> Void

    @Environment(\.locale) private var locale

    private func t(_ vi: String, _ en: String) -> String { V2.text(locale, vi, en) }

    var body: some View {
        V2Page {
            V2Row {
                V2Tile(title: t("Tai nghe & Bluetooth", "Headphones & Bluetooth"),
                       hint: t("Kiểu hiển thị, đúng như trên notch.", "How it looks on the notch.")) {
                    HStack(spacing: 12) {
                        ForEach(BluetoothAppearanceStyle.allCases, id: \.self) { style in
                            V2OptionCard(title: styleName(style),
                                         isSelected: connectivity.bluetoothAppearanceStyle == style,
                                         action: { connectivity.bluetoothAppearanceStyle = style }) {
                                bluetoothVisual(style)
                            }
                        }
                    }
                    .accessibilityIdentifier("settings.v2.alerts.bluetoothStyle")
                }
                .v2Span(2)

                V2Tile(title: t("Viền tai nghe", "Headphone outline")) {
                    V2ToggleList(items: [
                        .init(id: "batteryStroke", label: t("Viền theo màu pin", "Battery-colored outline"),
                              isOn: $connectivity.isBluetoothBatteryStrokeEnabled)
                    ])
                    Spacer(minLength: 0)
                }
            }

            V2Tile(title: t("\(rows.count) loại thông báo", "\(rows.count) alert types"),
                   hint: t("Bấm một dòng để mở trang chi tiết.", "Click a row to open its page."),
                   accessory: {
                       V2Pill(text: t("\(rows.filter { $0.isOn.wrappedValue }.count) đang bật",
                                      "\(rows.filter { $0.isOn.wrappedValue }.count) on"),
                              color: V2.green)
                   }) {
                VStack(spacing: 0) {
                    header
                    ForEach(rows) { row in
                        Rectangle().fill(.primary.opacity(0.08)).frame(height: 1)
                        alertRow(row)
                    }
                }
            }
        }
        .accessibilityIdentifier("settings.v2.alerts.root")
    }

    // MARK: Table

    private var header: some View {
        HStack(spacing: 12) {
            Text(verbatim: t("Thông báo", "Alert")).frame(maxWidth: .infinity, alignment: .leading)
            Text(verbatim: t("Trạng thái", "Status")).frame(width: 90, alignment: .leading)
            Color.clear.frame(width: 14)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.vertical, 6)
        .accessibilityHidden(true)
    }

    private func alertRow(_ row: AlertRow) -> some View {
        HStack(spacing: 12) {
            Button { onOpen(row.section) } label: {
                HStack(spacing: 10) {
                    Image(systemName: row.section.systemImage)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(width: 18)
                        .accessibilityHidden(true)
                    Text(verbatim: title(row.section)).font(.system(size: 13))
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text(verbatim: t("Mở trang chi tiết", "Opens its page")))

            Toggle(isOn: row.isOn) { Text(verbatim: title(row.section)) }
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(V2.green)
                .frame(width: 90, alignment: .leading)
                .accessibilityIdentifier("settings.v2.alerts.toggle.\(row.section.rawValue)")

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 14)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 40)
    }

    // MARK: Rows

    private struct AlertRow: Identifiable {
        let section: Section
        let isOn: Binding<Bool>
        var id: String { section.rawValue }
    }

    private var rows: [AlertRow] {
        sections.compactMap { section in
            guard let isOn = row(for: section) else { return nil }
            return AlertRow(section: section, isOn: isOn)
        }
    }

    private func row(for section: Section) -> Binding<Bool>? {
        switch section {
        case .network:
            return any([\.isNoInternetTemporaryActivityEnabled, \.isHotspotLiveActivityEnabled, \.isVpnLiveActivityEnabled], on: connectivity)
        case .bluetooth:
            return $connectivity.isBluetoothTemporaryActivityEnabled
        case .focus:
            return $connectivity.isFocusLiveActivityEnabled
        case .battery:
            return any([\.isChargerTemporaryActivityEnabled, \.isLowPowerTemporaryActivityEnabled, \.isFullPowerTemporaryActivityEnabled], on: battery)
        case .downloads:
            return $media.isDownloadsLiveActivityEnabled
        case .hud:
            return any([\.isVolumeHUDEnabled, \.isBrightnessHUDEnabled, \.isKeyboardHUDEnabled], on: hud)
        case .calendar:
            return $calendar.isCalendarLiveActivityEnabled
        case .timer:
            return $media.isTimerLiveActivityEnabled
        case .screenRecording:
            return any([\.isScreenRecordingLiveActivityEnabled, \.isScreenshotActivityEnabled], on: screenRecording)
        case .externalDevices:
            return $externalDevices.isExternalDrivesNotificationsEnabled
        default:
            return nil
        }
    }

    /// One switch for an alert made of several sub-alerts: on if any is on, sets all.
    private func any<Store: AnyObject>(_ paths: [ReferenceWritableKeyPath<Store, Bool>], on store: Store) -> Binding<Bool> {
        Binding(get: { paths.contains { store[keyPath: $0] } },
                set: { value in paths.forEach { store[keyPath: $0] = value } })
    }

    // MARK: Bluetooth visuals

    private func styleName(_ style: BluetoothAppearanceStyle) -> String {
        switch style {
        case .compact: return t("Gọn", "Compact")
        case .detailed: return t("Chi tiết", "Detailed")
        }
    }

    @ViewBuilder
    private func bluetoothVisual(_ style: BluetoothAppearanceStyle) -> some View {
        switch style {
        case .compact:
            HStack(spacing: 8) {
                Image(systemName: "airpodspro").font(.system(size: 13))
                Spacer(minLength: 0)
                Text(verbatim: "78%").font(.system(size: 12, weight: .semibold)).foregroundStyle(V2.green)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(width: 150, height: 28)
            .background(Capsule().fill(.black))
        case .detailed:
            HStack(spacing: 8) {
                Image(systemName: "airpodspro").font(.system(size: 16))
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: t("Đã kết nối", "Connected")).font(.system(size: 9)).foregroundStyle(.white.opacity(0.6))
                    Text(verbatim: "AirPods Pro").font(.system(size: 11, weight: .semibold))
                }
                Spacer(minLength: 0)
                Text(verbatim: "78").font(.system(size: 12, weight: .semibold)).foregroundStyle(V2.green)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(width: 170, height: 40)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.black))
        }
    }
}
