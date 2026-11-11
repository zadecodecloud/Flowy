import SwiftUI
internal import AppKit

enum SettingsWindowLayout {
    static let width: CGFloat = 960
    static let height: CGFloat = 700
}

struct SettingsRootView: View {
    private enum SelectionChangeOrigin {
        case sidebar
        case history
        case initial
    }

    @Environment(\.openURL) private var openURL
    @ObservedObject var powerService: PowerService
    @ObservedObject var settingsViewModel: SettingsViewModel

    let notchViewModel: NotchViewModel
    let notchEventCoordinator: NotchEventCoordinator
    let bluetoothViewModel: BluetoothViewModel
    let wifiViewModel: WifiViewModel
    let vpnViewModel: VpnViewModel
    let downloadViewModel: DownloadViewModel
    let nowPlayingViewModel: NowPlayingViewModel
    let timerViewModel: TimerViewModel
    let lockScreenManager: LockScreenManager

    private let viewModel: SettingsRootViewModel
    
    @Environment(\.colorScheme) private var colorScheme
    
    private enum ResetTarget: Identifiable {
        case section(SettingsRootViewModel.Section)
        case subPage(SettingsSubPage)

        var id: String {
            switch self {
            case .section(let s): return "section-\(s.rawValue)"
            case .subPage(let sp): return "subPage-\(sp.id)"
            }
        }
    }

    @StateObject private var permissionController = SettingsPermissionController()
    @State private var selectedSection: SettingsRootViewModel.Section
    @State private var selectionHistory: SettingsRootViewModel.SelectionHistory
    @State private var pendingResetTarget: ResetTarget?
    @State private var selectedGeneralTab: GeneralTab = .notch
    @State private var navigationPath: [SettingsSubPage] = []
    @State private var searchText = ""
    @State private var availableDisplays = NSScreen.availableNotchDisplays()
    @ObservedObject private var updater = SparkleUpdater.shared
    @ObservedObject private var licenses = LicenseStore.shared
    @State private var hadDeveloperAccess = false
    @State private var showsAlertsOverview = false
    @State private var showsLicense = false

    init(container: AppContainer) {
        self.init(
            powerService: container.powerService,
            settingsViewModel: container.settingsViewModel,
            notchViewModel: container.notchViewModel,
            notchEventCoordinator: container.notchEventCoordinator,
            bluetoothViewModel: container.bluetoothViewModel,
            wifiViewModel: container.wifiViewModel,
            vpnViewModel: container.vpnViewModel,
            downloadViewModel: container.downloadViewModel,
            nowPlayingViewModel: container.nowPlayingViewModel,
            timerViewModel: container.timerViewModel,
            lockScreenManager: container.lockScreenManager
        )
    }

    init(
        powerService: PowerService,
        settingsViewModel: SettingsViewModel,
        notchViewModel: NotchViewModel,
        notchEventCoordinator: NotchEventCoordinator,
        bluetoothViewModel: BluetoothViewModel,
        wifiViewModel: WifiViewModel,
        vpnViewModel: VpnViewModel,
        downloadViewModel: DownloadViewModel,
        nowPlayingViewModel: NowPlayingViewModel,
        timerViewModel: TimerViewModel,
        lockScreenManager: LockScreenManager
    ) {
        self.powerService = powerService
        self.settingsViewModel = settingsViewModel
        self.notchViewModel = notchViewModel
        self.notchEventCoordinator = notchEventCoordinator
        self.bluetoothViewModel = bluetoothViewModel
        self.wifiViewModel = wifiViewModel
        self.vpnViewModel = vpnViewModel
        self.downloadViewModel = downloadViewModel
        self.nowPlayingViewModel = nowPlayingViewModel
        self.timerViewModel = timerViewModel
        self.lockScreenManager = lockScreenManager
        let rootViewModel = SettingsRootViewModel(
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
            lockScreenManager: lockScreenManager
        )
        self.viewModel = rootViewModel
        let initialSelection = rootViewModel.initialSelection()
        _selectedSection = State(initialValue: initialSelection)
        _selectionHistory = State(initialValue: .init(initialSelection: initialSelection))
    }

    private func localized(_ key: String, fallback: String? = nil) -> String {
        settingsViewModel.application.appLanguage.locale.nf(key, fallback: fallback)
    }

    var body: some View {
        NavigationSplitView {
            SettingsV2Sidebar(
                groups: groupedSections,
                selected: selectedSection,
                searchText: $searchText,
                isPro: licenses.hasPro,
                isUpdateAvailable: updater.isUpdateAvailable,
                localized: { localized($0, fallback: $1) },
                onSelect: { applySelection($0, origin: .sidebar) },
                overviewGroup: showsAlertsOverview ? .alerts : nil,
                onOpenGroup: { group in
                    if let first = groupedSections.first(where: { $0.group == group })?.sections.first {
                        applySelection(first, origin: .sidebar)
                    }
                    showsAlertsOverview = true
                },
                isLicenseOpen: showsLicense,
                onOpenLicense: {
                    navigationPath.removeAll()
                    showsAlertsOverview = false
                    showsLicense = true
                }
            )
            .navigationSplitViewColumnWidth(min: 248, ideal: 268, max: 290)
        } detail: {
            NavigationStack(path: $navigationPath) {
                VStack(alignment: .leading, spacing: 0) {
                    settingsPageHeading
                    if showsLicense {
                        SettingsLicenseView()
                    } else if showsAlertsOverview {
                        SettingsAlertsOverviewView(
                            connectivity: settingsViewModel.connectivity,
                            battery: settingsViewModel.battery,
                            hud: settingsViewModel.hud,
                            media: settingsViewModel.mediaAndFiles,
                            calendar: settingsViewModel.calendar,
                            screenRecording: settingsViewModel.screenRecording,
                            externalDevices: settingsViewModel.externalDevices,
                            sections: groupedSections.first(where: { $0.group == .alerts })?.sections ?? [],
                            title: { localized($0.titleKey, fallback: $0.fallbackTitle) },
                            onOpen: { applySelection($0, origin: .sidebar) }
                        )
                    } else {
                        detailView(for: selectedSection)
                    }
                }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .scrollContentBackground(.hidden)
                    .navigationDestination(for: SettingsSubPage.self) { subPage in
                        VStack(alignment: .leading, spacing: 0) {
                            settingsPageHeading
                            subPageView(for: subPage)
                        }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .scrollContentBackground(.hidden)
                            .navigationBarBackButtonHidden(true)
                            .toolbar { toolbarContent(for: selectedSection) }
                    }
            }
        }
        .containerBackground(.clear, for: .window)
        .navigationTitle("")
        .onAppear {
            hadDeveloperAccess = licenses.hasDeveloperAccess
            applySelection(viewModel.initialSelection(), origin: .initial)
            updateWindowStyle()
        }
        .onChange(of: colorScheme) {
            updateWindowStyle()
        }
        .onChange(of: settingsViewModel.application.appearanceMode) {
            updateWindowStyle()
        }
        .onChange(of: licenses.revision) {
            if hadDeveloperAccess && !licenses.hasDeveloperAccess {
                viewModel.debugViewModel.resetAllPreviews()
            }
            hadDeveloperAccess = licenses.hasDeveloperAccess
            if !licenses.hasDeveloperAccess && selectedSection == .debug {
                applySelection(.about, origin: .sidebar)
            }
            if !licenses.hasDeveloperAccess && navigationPath.contains(.debug) {
                navigationPath.removeAll()
            }
        }
        .alert(item: $pendingResetTarget) { target in
            let title: String
            switch target {
            case .section(let section):
                if section == .general {
                    title = settingsViewModel.application.appLanguage.locale.nfFormat(
                        "settings.reset.title",
                        fallback: "Reset %@ settings?",
                        localized(selectedGeneralTab.titleKeyString, fallback: selectedGeneralTab.fallbackTitle)
                    )
                } else {
                    title = settingsViewModel.application.appLanguage.locale.nfFormat(
                        "settings.reset.title",
                        fallback: "Reset %@ settings?",
                        localized(section.titleKey, fallback: section.fallbackTitle)
                    )
                }
            case .subPage(let subPage):
                title = settingsViewModel.application.appLanguage.locale.nfFormat(
                    "settings.reset.title",
                    fallback: "Reset %@ settings?",
                    localized(subPage.titleKey, fallback: subPage.fallbackTitle)
                )
            }
            return Alert(
                title: Text(title),
                message: Text(localized("settings.reset.message")),
                primaryButton: .destructive(Text(localized("settings.reset.action"))) {
                    switch target {
                    case .section(let section):
                        if section == .general {
                            switch selectedGeneralTab {
                            case .notch:
                                settingsViewModel.application.resetNotch()
                                settingsViewModel.application.resetDisplay()
                            case .language:
                                settingsViewModel.application.resetLanguage()
                            case .other:
                                settingsViewModel.application.resetAppearance()
                                settingsViewModel.application.resetSystem()
                            }
                        } else {
                            viewModel.reset(section)
                        }
                    case .subPage(let subPage):
                        resetCurrentSubPage(subPage)
                    }
                },
                secondaryButton: .cancel(Text(localized("common.cancel")))
            )
        }
        .accessibilityIdentifier("settings.root")
        .environment(\.locale, settingsViewModel.application.appLanguage.locale)
        .preferredColorScheme(settingsViewModel.application.appearanceMode.preferredColorScheme)
        .background {
            ZStack {
                NotchGlassBackdrop(cornerRadius: 22, colorScheme: colorScheme, isWindowBackground: true)
                // v2: content sits on a near-solid plane so windows behind never show through
                // settings text; only a faint tint of the scene remains around the glass sidebar.
                (colorScheme == .dark ? Color(red: 14 / 255, green: 15 / 255, blue: 19 / 255).opacity(0.97) : Color(white: 0.96).opacity(0.95))
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SelectSettingsSection"))) { notification in
            if let section = notification.object as? SettingsRootViewModel.Section {
                applySelection(section, origin: .sidebar)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SelectSettingsSubPage"))) { notification in
            if let subPage = notification.object as? SettingsSubPage {
                switch subPage {
                case .about, .softwareUpdate, .support:
                    applySelection(.about, origin: .sidebar)
                case .permissions:
                    applySelection(.permissions, origin: .sidebar)
                case .notch:
                    applySelection(.general, origin: .sidebar)
                    selectedGeneralTab = .notch
                case .language, .appearance, .system:
                    applySelection(.about, origin: .sidebar)
                default:
                    applySelection(.general, origin: .sidebar)
                    navigationPath = [subPage]
                }
            }
        }
    }

    /// v2 page header: "Category / Page" breadcrumb over a hairline, subtitle below.
    private var settingsPageHeading: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: showsLicense ? "checkmark.seal" : showsAlertsOverview ? "bell" : selectedSection.systemImage)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                    .accessibilityHidden(true)
                Text("\(Text(verbatim: currentGroupTitle == currentTitle ? "" : "\(currentGroupTitle) / ").foregroundStyle(.secondary).fontWeight(.regular))\(Text(verbatim: currentTitle).fontWeight(.semibold))")
                    .font(.system(size: 16))
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
            }
            .frame(height: 52)
            .padding(.horizontal, 22)
            Rectangle().fill(.primary.opacity(0.08)).frame(height: 1)
            Text(currentSubtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 4)
        }
    }

    private var currentGroupTitle: String {
        if showsLicense { return currentTitle }
        let group = selectedSection.sidebarGroup
        return localized(group.titleKey ?? "", fallback: group.fallbackTitle)
    }

    private func updateWindowStyle() {
        guard let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "NotchFlowSettingsWindow" }) else {
            return
        }
        
        switch settingsViewModel.application.appearanceMode {
        case .system:
            window.appearance = nil
        case .light:
            window.appearance = NSAppearance(named: .aqua)
        case .dark:
            window.appearance = NSAppearance(named: .darkAqua)
        }
        
        window.backgroundColor = .clear
        window.isOpaque = false
        
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.toolbarStyle = .unified
    }

    private var selectionBinding: Binding<SettingsRootViewModel.Section> {
        Binding(
            get: { selectedSection },
            set: { applySelection($0, origin: .sidebar) }
        )
    }

    private var groupedSections: [(group: SettingsRootViewModel.SidebarGroup, sections: [SettingsRootViewModel.Section])] {
        SettingsRootViewModel.SidebarGroup.allCases.compactMap { group in
            let sections = viewModel.sections.filter { section in
                guard section.sidebarGroup == group, section != .faceID else { return false }
                let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                return query.isEmpty || localized(section.titleKey, fallback: section.fallbackTitle)
                    .localizedStandardContains(query)
            }
            guard !sections.isEmpty else { return nil }
            // The app's own General page leads its category.
            return (group, sections.sorted { $0 == .about && $1 != .about })
        }
    }

    private var canNavigateBack: Bool {
        !navigationPath.isEmpty || selectionHistory.canGoBack
    }

    private var canNavigateForward: Bool {
        navigationPath.isEmpty && selectionHistory.canGoForward
    }

    private func applySelection(_ section: SettingsRootViewModel.Section, origin: SelectionChangeOrigin) {
        guard section != .debug || licenses.hasDeveloperAccess else { return }
        showsAlertsOverview = false
        showsLicense = false
        navigationPath.removeAll()
        switch origin {
        case .sidebar:
            guard selectedSection != section ||
                    selectionHistory.currentSelection != section else {
                return
            }

            selectionHistory.record(section)
            selectedSection = section
            viewModel.persistSelection(section)

        case .history:
            guard selectedSection != section else { return }
            selectedSection = section
            viewModel.persistSelection(section)

        case .initial:
            selectionHistory = .init(initialSelection: section)
            selectedSection = section
        }
    }

    private func navigateBack() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
            return
        }
        guard let previousSection = selectionHistory.goBack() else { return }
        applySelection(previousSection, origin: .history)
    }

    private func navigateForward() {
        guard navigationPath.isEmpty else { return }
        guard let nextSection = selectionHistory.goForward() else { return }
        applySelection(nextSection, origin: .history)
    }

    @ViewBuilder
    private func detailView(for section: SettingsRootViewModel.Section) -> some View {
        switch section {
        case .general:
            detailContainer(for: section) {
                GeneralSettingsView(
                    powerService: powerService,
                    applicationSettings: settingsViewModel.application,
                    availableDisplays: $availableDisplays,
                    selectedTab: $selectedGeneralTab
                )
            }

        case .permissions:
            detailContainer(for: section) {
                PermissionsSettingsView(
                    permissionController: permissionController,
                    applicationSettings: settingsViewModel.application
                )
            }

        case .nowPlaying:
            detailContainer(for: section) {
                NowPlayingSettingsView(
                    settings: settingsViewModel.mediaAndFiles,
                    applicationSettings: settingsViewModel.application
                )
            }

        case .debug:
            detailContainer(for: section) {
                if licenses.hasDeveloperAccess {
                    DebugSettingsView(viewModel: viewModel.debugViewModel)
                }
            }
            
        case .calendar:
            detailContainer(for: section) {
                CalendarSettingsView(
                    settings: settingsViewModel.calendar
                )
            }

        case .externalDevices:
            detailContainer(for: section) {
                ExternalDevicesSettingsView(
                    settings: settingsViewModel.externalDevices
                )
            }
            
        case .downloads:
            detailContainer(for: section) {
                DownloadsSettingsView(
                    mediaSettings: settingsViewModel.mediaAndFiles,
                    appearanceSettings: settingsViewModel.application
                )
            }

        case .drop:
            detailContainer(for: section) {
                DragAndDropSettingsView(
                    mediaSettings: settingsViewModel.mediaAndFiles,
                    appearanceSettings: settingsViewModel.application
                )
            }

        case .mirror:
            detailContainer(for: section) {
                MirrorSettingsView(
                    mediaSettings: settingsViewModel.mediaAndFiles,
                    appearanceSettings: settingsViewModel.application
                )
            }

        case .screenRecording:
            detailContainer(for: section) {
                ScreenCaptureSettingsView(
                    settings: settingsViewModel.screenRecording,
                    appearanceSettings: settingsViewModel.application
                )
            }

        case .focus:
            detailContainer(for: section) {
                FocusSettingsView(
                    connectivitySettings: settingsViewModel.connectivity,
                    appearanceSettings: settingsViewModel.application
                )
            }

        case .bluetooth:
            detailContainer(for: section) {
                BluetoothSettingsView(
                    settings: settingsViewModel.connectivity,
                    applicationSettings: settingsViewModel.application
                )
            }

        case .network:
            detailContainer(for: section) {
                NetworkSettingsView(
                    connectivitySettings: settingsViewModel.connectivity,
                    appearanceSettings: settingsViewModel.application
                )
            }

        case .battery:
            detailContainer(for: section) {
                BatterySettingsView(
                    batterySettings: settingsViewModel.battery,
                    appearanceSettings: settingsViewModel.application
                )
            }

        case .hud:
            detailContainer(for: section) {
                HUDSettingsView(
                    settings: settingsViewModel.hud,
                    applicationSettings: settingsViewModel.application
                )
            }

        case .timer:
            detailContainer(for: section) {
                TimerSettingsView(
                    mediaSettings: settingsViewModel.mediaAndFiles,
                    appearanceSettings: settingsViewModel.application
                )
            }

        case .lockScreen:
            detailContainer(for: section) {
                LockScreenSettingsView(settings: settingsViewModel.lockScreen, applicationSettings: settingsViewModel.application)
            }

        case .faceID:
            detailContainer(for: section) {
                FaceIDSettingsView(
                    settings: settingsViewModel.faceID,
                    applicationSettings: settingsViewModel.application,
                    notchViewModel: notchViewModel
                )
            }

        case .about:
            detailContainer(for: section) {
                AboutAppSettingsView(
                    applicationSettings: settingsViewModel.application,
                    onRequestInternetAccess: {
                        notchEventCoordinator.requestInternetAccess()
                    }
                )
            }
        }
    }

    private func detailContainer<Content: View>(for section: SettingsRootViewModel.Section, @ViewBuilder content: () -> Content) -> some View {
        content()
            .accessibilityIdentifier(section.accessibilityIdentifier)
            .toolbar { toolbarContent(for: section) }
    }

    @ToolbarContentBuilder
    private func toolbarContent(for section: SettingsRootViewModel.Section) -> some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button {
                navigateBack()
            } label: {
                Image(systemName: "chevron.backward")
            }
            .disabled(!canNavigateBack)
            .help(localized("settings.navigation.back", fallback: "Back"))
            .keyboardShortcut("[", modifiers: [.command])
            .accessibilityLabel(Text(localized("settings.navigation.back", fallback: "Back")))
            .accessibilityIdentifier("settings.toolbar.back")

            Button {
                navigateForward()
            } label: {
                Image(systemName: "chevron.forward")
            }
            .disabled(!canNavigateForward)
            .help(localized("settings.navigation.forward", fallback: "Forward"))
            .keyboardShortcut("]", modifiers: [.command])
            .accessibilityLabel(Text(localized("settings.navigation.forward", fallback: "Forward")))
            .accessibilityIdentifier("settings.toolbar.forward")
        }

        if let subPage = navigationPath.last {
            if subPage == .permissions {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        permissionController.refresh()
                    } label: {
                        Text(localized("settings.permissions.action.check", fallback: "Check Permission"))
                            .padding(.horizontal, 5)
                    }
                    .help(localized("settings.permissions.action.check", fallback: "Check Permission"))
                    .accessibilityIdentifier("settings.toolbar.checkPermissions")
                }
            } else if subPage.canReset {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        pendingResetTarget = .subPage(subPage)
                    } label: {
                        Text(localized("settings.reset.action", fallback: "Reset"))
                            .padding(.horizontal, 5)
                    }
                    .help(
                        String(
                            format: localized("settings.reset.help.available", fallback: "Reset current tab to defaults"),
                            localized(subPage.titleKey, fallback: subPage.fallbackTitle)
                        )
                    )
                    .accessibilityIdentifier("settings.toolbar.resetCurrentSubPage")
                }
            }
        } else if section == .permissions {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    permissionController.refresh()
                } label: {
                    Text(localized("settings.permissions.action.check", fallback: "Check Permission"))
                        .padding(.horizontal, 5)
                }
                .help(localized("settings.permissions.action.check", fallback: "Check Permission"))
                .accessibilityIdentifier("settings.toolbar.checkPermissions")
            }
        } else if viewModel.canReset(section) && section != .general {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    pendingResetTarget = .section(section)
                } label: {
                    Text(localized("settings.reset.action", fallback: "Reset"))
                        .padding(.horizontal, 5)
                }
                .help(viewModel.resetHelpText(for: section, locale: settingsViewModel.application.appLanguage.locale))
                .accessibilityIdentifier("settings.toolbar.resetCurrentSection")
            }
        }
    }

    private func openInternetURL(_ url: URL) {
        guard notchEventCoordinator.requestInternetAccess() else { return }
        openURL(url)
    }

    @ViewBuilder
    private func subPageView(for subPage: SettingsSubPage) -> some View {
        switch subPage {
        case .appearance:
            OtherSettingsView(applicationSettings: settingsViewModel.application)
        case .notch:
            NotchSettingsView(
                powerService: powerService,
                applicationSettings: settingsViewModel.application,
                availableDisplays: $availableDisplays
            )
        case .language:
            LanguageSettingsView(applicationSettings: settingsViewModel.application)
        case .system:
            OtherSettingsView(applicationSettings: settingsViewModel.application)
        case .permissions:
            PermissionsSettingsView(permissionController: permissionController, applicationSettings: settingsViewModel.application)
        case .softwareUpdate:
            SoftwareUpdateSettingsView()
        case .support:
            SupportSettingsView(
                onRequestInternetAccess: {
                    notchEventCoordinator.requestInternetAccess()
                }
            )
        case .about:
            AboutAppSettingsView(
                applicationSettings: settingsViewModel.application,
                onRequestInternetAccess: {
                    notchEventCoordinator.requestInternetAccess()
                }
            )
        case .debug:
            if licenses.hasDeveloperAccess {
                DebugSettingsView(viewModel: viewModel.debugViewModel)
            }
        case .activityPriorities:
            ActivityPrioritiesSettingsView(applicationSettings: settingsViewModel.application)
        case .notchDisplay:
            DisplaySettingsView(applicationSettings: settingsViewModel.application, availableDisplays: $availableDisplays)
        case .gestures:
            GesturesSettingsView(applicationSettings: settingsViewModel.application)
        case .timer:
            TimerSettingsView(
                mediaSettings: settingsViewModel.mediaAndFiles,
                appearanceSettings: settingsViewModel.application
            )
        case .externalDrives:
            ExternalDrivesNotificationsSettingsView(
                settings: settingsViewModel.externalDevices
            )
        }
    }

    private var currentTitle: String {
        if showsLicense { return localized("settings.license.title", fallback: "License") }
        if showsAlertsOverview && navigationPath.isEmpty {
            return localized("settings.overview.title", fallback: "Overview")
        }
        if let subPage = navigationPath.last {
            return localized(subPage.titleKey, fallback: subPage.fallbackTitle)
        }
        return localized(selectedSection.titleKey, fallback: selectedSection.fallbackTitle)
    }

    private var currentSubtitle: String {
        if showsLicense {
            return localized("settings.license.subtitle", fallback: "Activate NotchFlow Pro on this Mac.")
        }
        if showsAlertsOverview && navigationPath.isEmpty {
            return localized("settings.overview.alerts.subtitle", fallback: "Every alert the notch can show, in one place.")
        }
        if let subPage = navigationPath.last {
            return localized(subPage.subtitleKey, fallback: subPage.fallbackSubtitle)
        }
        return localized(selectedSection.subtitleKey, fallback: selectedSection.fallbackSubtitle)
    }

    private func resetCurrentSubPage(_ page: SettingsSubPage) {
        switch page {
        case .appearance:
            settingsViewModel.application.resetAppearance()
        case .system:
            settingsViewModel.application.resetSystem()
        case .notch:
            settingsViewModel.application.resetNotch()
            settingsViewModel.application.resetDisplay()
        case .language:
            settingsViewModel.application.resetLanguage()
        case .activityPriorities:
            settingsViewModel.application.resetNotchContentPriorities()
        case .notchDisplay:
            settingsViewModel.application.resetDisplay()
        case .gestures:
            settingsViewModel.application.resetGestures()
        case .timer:
            settingsViewModel.mediaAndFiles.resetTimer()
        case .externalDrives:
            settingsViewModel.externalDevices.reset()
        default:
            break
        }
    }
}

