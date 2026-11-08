import SwiftUI

struct MirrorSettingsView: View {
    @ObservedObject var mediaSettings: MediaAndFilesSettingsStore
    @ObservedObject var appearanceSettings: ApplicationSettingsStore

    var body: some View {
        SettingsPageScrollView {
            mirrorActivity
            mirrorAppearance
        }
    }

    private var mirrorActivity: some View {
        SettingsCard(title: "settings.mirror.card.activity") {
            SettingsToggleRow(
                title: "settings.mirror.liveActivity.title",
                description: "settings.mirror.liveActivity.desc",
                systemImage: "camera.fill",
                color: .purple,
                isOn: $mediaSettings.isMirrorLiveActivityEnabled,
                accessibilityIdentifier: "settings.activities.live.mirror"
            )
        }
    }

    private var mirrorAppearance: some View {
        SettingsCard(title: "settings.mirror.card.appearance") {
            SettingsToggleRow(
                title: "settings.mirror.flipped.title",
                description: "settings.mirror.flipped.desc",
                systemImage: "arrow.left.and.right",
                color: .teal,
                isOn: $mediaSettings.isMirrorImageFlipped,
                accessibilityIdentifier: "settings.activities.live.mirror.flipped"
            )
        }
    }
}
