import SwiftUI
internal import AppKit

struct DragAndDropSettingsView: View {
    @ObservedObject var mediaSettings: MediaAndFilesSettingsStore
    @ObservedObject var appearanceSettings: ApplicationSettingsStore
    @ObservedObject private var licenses = LicenseStore.shared
        
    var body: some View {
        SettingsPageScrollView {
            dragAndDropActivity
            dragAndDropConfiguration
        }
    }
    
    private var dragAndDropActivity: some View {
        SettingsCard(title: "settings.drop.card.activity") {
            SettingsToggleRow(
                title: "settings.drop.dragAndDrop.title",
                description: "settings.drop.dragAndDrop.desc",
                systemImage: "tray.and.arrow.down.fill",
                color: .gray,
                stroke: true,
                isOn: $mediaSettings.isDragAndDropLiveActivityEnabled,
                accessibilityIdentifier: "settings.activities.live.drop"
            )
            
            Divider()
                .opacity(0.6)
                .padding(.leading, 43)
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            SettingsToggleRow(
                title: "settings.drop.airDrop.title",
                description: "settings.drop.airDrop.desc",
                imageName: "airdrop.white",
                color: .blue,
                isOn: $mediaSettings.isAirDropLiveActivityEnabled,
                accessibilityIdentifier: "settings.activities.live.drop.airdrop"
            )
            
            Divider()
                .opacity(0.6)
                .padding(.leading, 43)
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            SettingsToggleRow(
                title: "settings.drop.trayActivity.title",
                description: "settings.drop.trayActivity.desc",
                systemImage: "tray.full.fill",
                color: .black,
                stroke: true,
                isOn: $mediaSettings.isTrayLiveActivityEnabled,
                accessibilityIdentifier: "settings.activities.live.drop.tray"
            )
            .disabled(!licenses.hasPro)
            if !licenses.hasPro {
                Text(appearanceSettings.appLanguage.locale.language.languageCode?.identifier == "vi" ? "File Tray cần NotchFlow Pro. Các tệp đã lưu vẫn được giữ lại." : "File Tray requires NotchFlow Pro. Existing files are retained.")
                    .font(.caption).foregroundStyle(.secondary)
                if let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                    .appendingPathComponent("NotchFlow/FileTray", isDirectory: true),
                   FileManager.default.fileExists(atPath: url.path) {
                    Button(appearanceSettings.appLanguage.locale.language.languageCode?.identifier == "vi" ? "Mở thư mục tệp đã lưu" : "Open saved files") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
    
    private var dragAndDropConfiguration: some View {
        SettingsCard(title: "settings.drop.card.target") {
            SettingsMenuRow(
                title: "settings.drop.targetMode.title",
                description: "settings.drop.targetMode.desc",
                options: Array(DragAndDropActivityMode.allCases),
                optionTitle: { $0.title },
                accessibilityIdentifier: "settings.activities.live.drop.mode",
                selection: $mediaSettings.dragAndDropActivityMode
            )
            
            Divider()
                .opacity(0.6)
            
            SettingsMenuRow(
                title: "settings.drop.trayUsage.title",
                description: "settings.drop.trayUsage.desc",
                options: Array(FileTrayUsageMode.allCases),
                optionTitle: { $0.title },
                accessibilityIdentifier: "settings.activities.live.drop.trayUsage",
                selection: $mediaSettings.fileTrayUsageMode
            )
            .disabled(!licenses.hasPro)
            
            if mediaSettings.fileTrayUsageMode == .moveOriginals {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.yellow)
                    
                    Text("If the original is moved to the tray and deleted from there, you can restore it in the system trash.")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondary)
                }
            }
        }
    }
}
