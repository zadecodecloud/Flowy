//
//  MenuBarMenu.swift
//  NotchFlow
//
//

import SwiftUI

struct MenuBarMenu: View {
    @ObservedObject private var updater = SparkleUpdater.shared
    @AppStorage(GeneralSettingsStorage.Keys.appLanguage) private var appLanguageRaw: String = NotchLanguage.english.rawValue

    private var locale: Locale {
        NotchLanguage.resolved(appLanguageRaw).locale
    }

    private var localizedVersionText: String {
        locale.nfFormat(
            "menuBar.version",
            fallback: "Version: %@",
            AppVersionText.appVersionText
        )
    }
    
    var body: some View {
        Group {
            Text(verbatim: localizedVersionText)
            
            Divider()
            
            Button {
                updater.checkForUpdates()
            } label: {
                Image(systemName: "arrow.down.circle")
                Text(locale.nf("menuBar.checkForUpdates", fallback: "Check for Updates"))
            }
            .disabled(!updater.canCheckForUpdates)
            
            Button {
                SettingsWindowController.shared.showWindow()
            } label: {
                Image(systemName: "gearshape")
                Text(locale.nf("menuBar.settings", fallback: "Settings"))
            }
            
            Divider()
            
            Button(action: { AppRelauncher.restartApp() }) {
                Image(systemName: "arrow.trianglehead.2.counterclockwise.rotate.90")
                Text(locale.nf("menuBar.restart", fallback: "Restart"))
            }
            
            Button(action: { NSApplication.shared.terminate(nil) }) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text(locale.nf("menuBar.quit", fallback: "Quit"))
            }
        }
    }
}
