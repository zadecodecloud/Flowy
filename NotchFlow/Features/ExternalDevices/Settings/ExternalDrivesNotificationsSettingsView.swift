import SwiftUI

struct ExternalDrivesNotificationsSettingsView: View {
    @ObservedObject var settings: ExternalDevicesSettingsStore

    private var notificationDurationRange: ClosedRange<Double> {
        Double(SettingsStoreBase.notificationDurationRange.lowerBound)...Double(SettingsStoreBase.notificationDurationRange.upperBound)
    }

    var body: some View {
        SettingsPageScrollView {
            drivesActivity
        }
    }

    private var drivesActivity: some View {
        SettingsCard(title: "settings.notifications.card.activity") {
            SettingsToggleRow(
                title: "settings.notifications.externalDrives.enabled",
                description: "settings.notifications.externalDrives.enabled.description",
                systemImage: "externaldrive.fill",
                color: .gray,
                isOn: $settings.isExternalDrivesNotificationsEnabled,
                accessibilityIdentifier: "settings.notifications.externalDrives.toggle"
            )

            Divider()
                .opacity(0.6)
                .padding(.leading, 43)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)

            SettingsToggleRow(
                title: "settings.notifications.externalDrives.showEjected.title",
                description: "settings.notifications.externalDrives.showEjected.desc",
                systemImage: "eject.circle.fill",
                color: .blue,
                isOn: $settings.isExternalDrivesShowEjectedEnabled,
                accessibilityIdentifier: "settings.notifications.externalDrives.showEjected"
            )
            
            Divider().opacity(0.6)

            SettingsButtonRow(
                title: "settings.notifications.externalDrives.systemNotifications.title",
                description: "settings.notifications.externalDrives.systemNotifications.desc",
                systemImage: "exclamationmark.triangle.fill",
                iconSize: 20,
                iconColor: .yellow,
                color: .clear,
                buttonTitle: "settings.notifications.externalDrives.systemNotifications.button",
                accessibilityIdentifier: "settings.notifications.externalDrives.systemNotifications",
                action: openSystemNotificationSettings
            )
        }
    }
    
    private func openSystemNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=com.apple.finder"),
           NSWorkspace.shared.open(url) {
            return
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension"),
           NSWorkspace.shared.open(url) {
            return
        }
        if let fallbackURL = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(fallbackURL)
        }
    }
}
