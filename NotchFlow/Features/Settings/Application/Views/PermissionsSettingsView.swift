import SwiftUI

struct PermissionsSettingsView: View {
    @ObservedObject var permissionController: SettingsPermissionController
    @ObservedObject var applicationSettings: ApplicationSettingsStore
    @State private var imageAppear = false

    private func localized(_ key: String, fallback: String) -> String {
        applicationSettings.appLanguage.locale.nf(key, fallback: fallback)
    }

    var body: some View {
        V2Page {
            permissionsCard
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                imageAppear = true
            }
            permissionController.refresh()
        }
    }

    private var permissionsCard: some View {
        let items = permissionController.permissionItems
        let granted = items.filter(\.isGranted).count
        return V2Tile(title: localized("settings.v2.permissions.title", fallback: "Access"),
                      hint: localized("settings.v2.permissions.hint", fallback: "Each permission is only asked for when you use that feature."),
                      accessory: {
                          V2Pill(text: "\(granted) / \(items.count)",
                                 color: granted == items.count ? V2.green : V2.orange)
                      }) {
            ForEach(Array(permissionController.permissionItems.enumerated()), id: \.element.id) { index, item in
                permissionRow(for: item)

                if index < permissionController.permissionItems.count - 1 {
                    Rectangle().fill(.primary.opacity(0.08)).frame(height: 1).padding(.leading, 42)
                }
            }
        }
    }

    @ViewBuilder
    private func permissionRow(for item: PermissionItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            if let assetImageName = item.assetImageName {
                SettingsIconBadge(
                    imageName: assetImageName,
                    tint: item.tintColor,
                    size: 30,
                    iconColor: item.iconColor,
                    iconSize: 14,
                    cornerRadius: 9
                )
            } else {
                SettingsIconBadge(
                    systemImage: item.systemImage,
                    tint: item.tintColor,
                    size: 30,
                    iconColor: item.iconColor,
                    iconSize: 14,
                    cornerRadius: 9
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 8) {
                    Text(localized(item.titleKey, fallback: item.fallbackTitle))

                    V2Pill(text: localized(item.isGranted ? "settings.permissions.status.granted" : "settings.permissions.status.needsAccess",
                                           fallback: item.isGranted ? "Granted" : "Needs access"),
                           color: item.isGranted ? V2.green : V2.orange)
                }

                Text(localized(item.descriptionKey, fallback: item.fallbackDescription))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            if let actionTitleKey = item.actionTitleKey,
               let fallbackActionTitle = item.fallbackActionTitle {
                let isOpenPrivacySettings = actionTitleKey == "settings.permissions.action.openPrivacySettings"

                Button {
                    permissionController.performAction(for: item.kind)
                } label: {
                    if isOpenPrivacySettings {
                        Image(systemName: "gearshape")
                    } else {
                        Text(localized(actionTitleKey, fallback: fallbackActionTitle))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(isOpenPrivacySettings ? localized(actionTitleKey, fallback: fallbackActionTitle) : "")
                .accessibilityLabel(localized(actionTitleKey, fallback: fallbackActionTitle))
                .accessibilityIdentifier("\(item.accessibilityIdentifier).action")
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)
            }
        }
        .modifier(SettingsAccessibilityModifier(identifier: item.accessibilityIdentifier))
    }
}
