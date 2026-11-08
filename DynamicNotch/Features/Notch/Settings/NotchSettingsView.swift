//
//  NotchSettingsView.swift
//  DynamicNotch
//

import SwiftUI
internal import AppKit

struct NotchSettingsView: View {
    @ObservedObject var powerService: PowerService
    @ObservedObject var applicationSettings: ApplicationSettingsStore
    @Binding var availableDisplays: [NotchDisplayOption]

    var body: some View {
        SettingsPageScrollView {
            appearancePreviewSection
            appearanceCard
            otherSettings
        }
        .background(Color(nsColor: .textBackgroundColor))
        .accessibilityIdentifier("settings.notch.root")
        .onAppear(perform: refreshAvailableDisplays)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            refreshAvailableDisplays()
        }
    }
    
    private var appearancePreviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("notchflow.notch.background.title")
                    .font(.system(size: 27, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
                Text("notchflow.notch.background.description")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            ExpandedNotchAppearancePreview(style: applicationSettings.notchBackgroundStyle,
                                          transparency: applicationSettings.notchGlassTransparency)

            HStack {
                Text("notchflow.notch.background.whenExpanded")
                Spacer()
                Picker("notchflow.notch.background.whenExpanded", selection: $applicationSettings.notchBackgroundStyle) {
                    ForEach(NotchBackgroundStyle.availableOptions, id: \.self) { style in
                        Text(style.title).tag(style)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()
                .accessibilityIdentifier("settings.notch.backgroundStyle")
            }

            if applicationSettings.notchBackgroundStyle == .glass {
                Divider()
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 18) {
                        transparencyLabel.fixedSize(horizontal: true, vertical: false)
                        Spacer(minLength: 0)
                        transparencyControl.frame(width: 185)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        transparencyLabel
                        transparencyControl
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private var transparencyLabel: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("notchflow.notch.glassTransparency.title")
            Text("notchflow.notch.glassTransparency.description")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var transparencyControl: some View {
        HStack(spacing: 10) {
            Slider(value: Binding(get: { applicationSettings.notchGlassTransparency * 100 },
                                  set: { applicationSettings.notchGlassTransparency = $0 / 100 }),
                   in: 0...100, step: 5)
                .accessibilityLabel(Text("notchflow.notch.glassTransparency.title"))
                .accessibilityValue(Text(applicationSettings.notchGlassTransparency, format: .percent.precision(.fractionLength(0))))
                .accessibilityIdentifier("settings.notch.glassTransparency")
            Text(applicationSettings.notchGlassTransparency, format: .percent.precision(.fractionLength(0)))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 38, alignment: .trailing)
                .accessibilityHidden(true)
        }
    }

    private var appearanceCard: some View {
        SettingsCard {
            SettingsToggleRow(
                title: "settings.notch.showStroke.title",
                description: "settings.notch.showStroke.desc",
                systemImage: "inset.filled.capsule",
                color: .black,
                stroke: true,
                isOn: $applicationSettings.isShowNotchStrokeEnabled,
                accessibilityIdentifier: "settings.general.showNotchStroke"
            )
            
            Divider().opacity(0.6)
            
            SettingsSliderRow(
                title: "settings.notch.strokeOpacity.title",
                description: "settings.notch.strokeOpacity.desc",
                range: 0...100,
                step: 5,
                fractionLength: 0,
                suffix: "%",
                accessibilityIdentifier: "settings.general.notchStrokeOpacity",
                value: Binding(
                    get: { ((applicationSettings.notchStrokeOpacity / ApplicationSettingsStore.maxNotchStrokeOpacity) * 100).rounded() },
                    set: { applicationSettings.notchStrokeOpacity = ($0 / 100) * ApplicationSettingsStore.maxNotchStrokeOpacity }
                )
            )
            
            Divider().opacity(0.6)
            
            SettingsSliderRow(
                title: "settings.notch.width.title",
                description: "settings.notch.width.desc",
                range: -5...5,
                step: 1,
                fractionLength: 0,
                suffix: "px",
                accessibilityIdentifier: "settings.general.notchWidth",
                value: Binding(
                    get: { Double(applicationSettings.notchWidth) },
                    set: { applicationSettings.notchWidth = Int($0.rounded()) }
                )
            )
            
            Divider().opacity(0.6)
            
            SettingsSliderRow(
                title: "settings.notch.height.title",
                description: "settings.notch.height.desc",
                range: -1...1,
                step: 1,
                fractionLength: 0,
                suffix: "px",
                accessibilityIdentifier: "settings.general.notchHeight",
                value: Binding(
                    get: { Double(applicationSettings.notchHeight) },
                    set: { applicationSettings.notchHeight = Int($0.rounded()) }
                )
            )
        }
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
