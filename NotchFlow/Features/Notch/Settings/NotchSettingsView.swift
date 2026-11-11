//
//  NotchSettingsView.swift
//  NotchFlow
//

import SwiftUI
internal import AppKit

struct NotchSettingsView: View {
    @ObservedObject var powerService: PowerService
    @ObservedObject var applicationSettings: ApplicationSettingsStore
    @Binding var availableDisplays: [NotchDisplayOption]

    @Environment(\.locale) private var locale

    private func t(_ vi: String, _ en: String) -> String { V2.text(locale, vi, en) }

    var body: some View {
        V2Page {
            V2Row {
                V2Stage(height: 262, caption: t("Mẫu tĩnh · không điều khiển nhạc", "Static sample · never controls music")) {
                    ExpandedNotchAppearancePreview(style: applicationSettings.notchBackgroundStyle,
                                                  transparency: applicationSettings.notchGlassTransparency)
                        .frame(maxHeight: .infinity, alignment: .top)
                } bar: {
                    V2Chips(options: NotchBackgroundStyle.availableOptions,
                            selection: $applicationSettings.notchBackgroundStyle,
                            title: { Text($0.title) },
                            identifier: "settings.notch.backgroundStyle")
                }
                .v2Span(2)

                V2ValueTile(
                    title: t("Độ trong của kính", "Glass clarity"),
                    hint: applicationSettings.notchBackgroundStyle == .glass
                        ? t("Nửa dưới khi mở rộng", "Lower half when expanded")
                        : t("Chỉ dùng khi chọn kính", "Only used with glass"),
                    valueText: applicationSettings.notchGlassTransparency.formatted(.percent.precision(.fractionLength(0))),
                    value: Binding(get: { applicationSettings.notchGlassTransparency * 100 },
                                   set: { applicationSettings.notchGlassTransparency = $0 / 100 }),
                    range: 0...100, step: 5,
                    identifier: "settings.notch.glassTransparency")
                .disabled(applicationSettings.notchBackgroundStyle != .glass)
                .opacity(applicationSettings.notchBackgroundStyle == .glass ? 1 : 0.55)
            }

            V2Row {
                V2ValueTile(
                    title: t("Độ mờ của viền", "Outline opacity"),
                    hint: t("Viền theo màu nội dung", "Outline follows content color"),
                    valueText: "\(Int(strokePercent))%",
                    value: Binding(get: { strokePercent },
                                   set: { applicationSettings.notchStrokeOpacity = ($0 / 100) * ApplicationSettingsStore.maxNotchStrokeOpacity }),
                    range: 0...100, step: 5,
                    identifier: "settings.general.notchStrokeOpacity")
                .disabled(!applicationSettings.isShowNotchStrokeEnabled)
                .opacity(applicationSettings.isShowNotchStrokeEnabled ? 1 : 0.55)
                V2ValueTile(
                    title: t("Chiều rộng", "Width"),
                    hint: t("Tinh chỉnh theo tai thỏ", "Fine-tune to the notch"),
                    valueText: signedPixels(applicationSettings.notchWidth),
                    value: Binding(get: { Double(applicationSettings.notchWidth) },
                                   set: { applicationSettings.notchWidth = Int($0.rounded()) }),
                    range: -5...5, step: 1,
                    identifier: "settings.general.notchWidth")
                V2ValueTile(
                    title: t("Chiều cao", "Height"),
                    hint: t("Tinh chỉnh theo tai thỏ", "Fine-tune to the notch"),
                    valueText: signedPixels(applicationSettings.notchHeight),
                    value: Binding(get: { Double(applicationSettings.notchHeight) },
                                   set: { applicationSettings.notchHeight = Int($0.rounded()) }),
                    range: -1...1, step: 1,
                    identifier: "settings.general.notchHeight")
            }

            V2Row(columns: 2) {
                V2Tile(title: t("Cách mở", "How it opens"),
                       hint: t("Notch mở khi nào.", "When the notch expands.")) {
                    V2Chips(options: NotchExpandInteraction.allCases,
                            selection: $applicationSettings.notchExpandInteraction,
                            title: { Text($0.title) },
                            identifier: "settings.notch.v2.expandInteraction")
                    Spacer(minLength: 0)
                }
                V2Tile(title: t("Hiệu ứng", "Effects")) {
                    V2ToggleList(items: [
                        .init(id: "stroke", label: t("Hiện viền", "Show outline"),
                              note: t("Viền mỏng theo màu thông báo", "Thin outline in the alert's color"),
                              isOn: $applicationSettings.isShowNotchStrokeEnabled),
                        .init(id: "haptic", label: t("Rung nhẹ khi rê chuột", "Haptic on hover"),
                              note: t("Trên trackpad Force Touch", "On Force Touch trackpads"),
                              isOn: $applicationSettings.isNotchHoverHapticEnabled,
                              isDisabled: applicationSettings.notchExpandInteraction != .hover),
                        .init(id: "fullscreen", label: t("Ẩn khi toàn màn hình", "Hide in full screen"),
                              isOn: $applicationSettings.isNotchHiddenInFullscreenEnabled)
                    ])
                }
            }

            otherSettings
                .padding(.horizontal, -10)
        }
        .accessibilityIdentifier("settings.notch.root")
        .onAppear(perform: refreshAvailableDisplays)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            refreshAvailableDisplays()
        }
    }

    private var strokePercent: Double {
        ((applicationSettings.notchStrokeOpacity / ApplicationSettingsStore.maxNotchStrokeOpacity) * 100).rounded()
    }

    private func signedPixels(_ value: Int) -> String {
        value > 0 ? "+\(value) px" : "\(value) px"
    }

    private var otherSettings: some View {
        SettingsCard(spacing: 0, padding: 0) {
            SettingsNavigationRowView(
                title: "settings.notch.priorities.title",
                description: "settings.notch.priorities.subtitle",
                systemImage: "list.bullet",
                color: .red,
                accessibilityIdentifier: "settings.notch.priorities",
                position: .first,
                value: SettingsSubPage.activityPriorities
            )
            
            SettingsNavigationRowView(
                title: "settings.notch.display.title",
                description: "settings.notch.display.subtitle",
                systemImage: "display.2",
                color: .black,
                stroke: true,
                accessibilityIdentifier: "settings.notch.display",
                position: .middle,
                value: SettingsSubPage.notchDisplay
            )
            
            SettingsNavigationRowView(
                title: "settings.notch.gestures.navTitle",
                description: "settings.notch.gestures.subtitle",
                systemImage: "hand.draw.badge.ellipsis.fill",
                color: LinearGradient.orangeGradient,
                accessibilityIdentifier: "settings.notch.gestures",
                position: .last,
                value: SettingsSubPage.gestures
            )
        }
    }
    
    private func refreshAvailableDisplays() {
        availableDisplays = NSScreen.availableNotchDisplays()
        applicationSettings.syncPreferredDisplayMetadata()
    }
}
