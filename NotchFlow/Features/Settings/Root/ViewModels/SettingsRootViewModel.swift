import Foundation

@MainActor
final class SettingsRootViewModel {
    let debugViewModel: DebugSettingsViewModel

    private let settingsViewModel: SettingsViewModel
    private let defaults: UserDefaults
    private static let selectionKey = "settings.root.selection"

    init(
        settingsViewModel: SettingsViewModel,
        notchViewModel: NotchViewModel? = nil,
        notchEventCoordinator: NotchEventCoordinator? = nil,
        bluetoothViewModel: BluetoothViewModel? = nil,
        powerService: PowerService? = nil,
        wifiViewModel: WifiViewModel? = nil,
        vpnViewModel: VpnViewModel? = nil,
        downloadViewModel: DownloadViewModel? = nil,
        nowPlayingViewModel: NowPlayingViewModel? = nil,
        timerViewModel: TimerViewModel? = nil,
        lockScreenManager: LockScreenManager? = nil,
        localTimerViewModel: LocalTimerViewModel? = nil,
        calendarViewModel: CalendarViewModel? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.settingsViewModel = settingsViewModel
        self.defaults = defaults

        self.debugViewModel = Self.makeDebugViewModel(
            settingsViewModel: settingsViewModel,
            notchViewModel: notchViewModel,
            notchEventCoordinator: notchEventCoordinator,
            bluetoothViewModel: bluetoothViewModel,
            powerService: powerService,
            wifiViewModel: wifiViewModel,
            vpnViewModel: vpnViewModel,
            downloadViewModel: downloadViewModel,
            nowPlayingViewModel: nowPlayingViewModel,
            timerViewModel: timerViewModel,
            lockScreenManager: lockScreenManager,
            localTimerViewModel: localTimerViewModel,
            calendarViewModel: calendarViewModel
        )
    }

    var sections: [Section] {
        Section.allCases.filter {
            ($0 != .debug || LicenseStore.shared.hasDeveloperAccess) &&
            ($0 != .hud || NotchFeatures.isHardwareHUDEnabled)
        }
    }

    func initialSelection() -> Section {
        let selected = Section.initialSelection(storedValue: defaults.string(forKey: Self.selectionKey))
        return selected == .debug && !LicenseStore.shared.hasDeveloperAccess ? .general : selected
    }

    func persistSelection(_ selection: Section) {
        defaults.set(selection.rawValue, forKey: Self.selectionKey)
    }

    func canReset(_ section: Section) -> Bool {
        section.resetGroup != nil
    }

    func reset(_ section: Section) {
        guard let group = section.resetGroup else { return }
        settingsViewModel.reset(group)
    }

    func resetHelpText(for section: Section?, locale: Locale) -> String {
        guard let section else {
            return locale.nf(
                "settings.reset.help.none",
                fallback: "No settings tab selected"
            )
        }

        guard canReset(section) else {
            return locale.nfFormat(
                "settings.reset.help.unavailable",
                fallback: "%@ has no resettable settings",
                section.localizedTitle(locale: locale)
            )
        }

        return locale.nfFormat(
            "settings.reset.help.available",
            fallback: "Reset %@ settings to defaults",
            section.localizedTitle(locale: locale)
        )
    }
}
