import SwiftUI
import UniformTypeIdentifiers

extension AppDelegate {
    func createNotchWindow() {
        guard let screen =
            NSScreen.preferredNotchScreen(for: settingsViewModel) ??
            NSScreen.preferredNotchScreen(for: settingsViewModel.application) ??
            NSScreen.preferredNotchScreen(for: .main) ??
            NSScreen.screens.first
        else {
            return
        }

        let frame = OverlayWindowLayout.topAnchoredFrame(
            on: screen,
            size: OverlayWindowLayout.appCanvasSize
        )

        window = OverlayPanelFactory.makePanel(
            frame: frame,
            level: OverlayWindowLevel.interactiveNotch
        )

        let hostingView = NotchHostingView(
            rootView: NotchView(
                notchEventCoordinator: notchEventCoordinator,
                notchViewModel: notchViewModel,
                airDropViewModel: airDropViewModel,
                airDropController: airDropController,
                settingsViewModel: settingsViewModel
            )
        )

        // Window set-up from notchflow-clean's `ShellOverlayPanel`: the panel is not moved to
        // a SkyLight space, and it ignores the mouse except while the pointer is over the
        // visible shape (`NotchShellInputController` lifts that), so clicks, drags and file
        // drops reach it there and pass through everywhere else.
        hostingView.sizingOptions = []
        hostingView.safeAreaRegions = []
        window.contentView = hostingView
        window.collectionBehavior = OverlayPanelFactory.collectionBehavior(
            includesFullscreenAuxiliary: true
        )
        window.ignoresMouseEvents = true
        updateWindowFrame()
        reRegisterDragDestination(for: window)
        startShellInput()
    }

    func startShellInput() {
        shellInput?.stop()
        let input = NotchShellInputController(
            panel: window,
            notchViewModel: notchViewModel,
            hitRect: { [weak self] in
                guard let self, let window = self.window, window.isVisible else { return nil }
                return self.activeNotchScreenRect
            },
            menuProvider: { [weak self] in self?.makeNotchMenu() ?? NSMenu() }
        )
        input.start()
        shellInput = input
    }

    /// The notch's right-click menu: the pages, then update, settings, restart and quit.
    func makeNotchMenu() -> NSMenu {
        let locale = settingsViewModel.application.appLanguage.locale
        let menu = NSMenu()
        let pages: [(NotchPage, String, String)] = [
            (.media, "notchflow.page.music", "Music"),
            (.tray, "notchflow.page.tray", "Files"),
            (.mirror, "notchflow.page.mirror", "Mirror")
        ]
        let available = notchEventCoordinator.availablePages
        for (page, key, fallback) in pages {
            let item = NotchMenuItem(title: locale.nf(key, fallback: fallback)) { [weak self] in
                self?.notchEventCoordinator.openPage(page)
            }
            item.isEnabled = available.contains(page)
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let updates = NotchMenuItem(title: locale.nf("menuBar.checkForUpdates", fallback: "Check for Updates"),
                                    symbol: "arrow.down.circle") { SparkleUpdater.shared.checkForUpdates() }
        updates.isEnabled = SparkleUpdater.shared.canCheckForUpdates
        menu.addItem(updates)
        menu.addItem(NotchMenuItem(title: locale.nf("menuBar.settings", fallback: "Settings"),
                                   symbol: "gearshape") { SettingsWindowController.shared.showWindow() })
        menu.addItem(.separator())
        menu.addItem(NotchMenuItem(title: locale.nf("menuBar.restart", fallback: "Restart"),
                                   symbol: "arrow.trianglehead.2.counterclockwise.rotate.90") { AppRelauncher.restartApp() })
        menu.addItem(NotchMenuItem(title: locale.nf("menuBar.quit", fallback: "Quit"),
                                   symbol: "rectangle.portrait.and.arrow.right") { NSApp.terminate(nil) })
        menu.autoenablesItems = false
        return menu
    }

    @objc
    func updateWindowFrame() {
        guard let window else { return }

        notchViewModel.updateDimensions()

        guard let screen = NSScreen.preferredNotchScreen(for: settingsViewModel) else {
            clearNowPlayingPrimaryWindowPresentationState()
            window.orderOut(nil)
            return
        }

        let targetFrame = OverlayWindowLayout.topAnchoredFrame(
            on: screen,
            size: window.frame.size
        )

        window.collectionBehavior = OverlayPanelFactory.collectionBehavior(
            includesFullscreenAuxiliary: true
        )
        window.setFrame(targetFrame, display: true, animate: false)
        updatePrimaryWindowPresentation(on: screen)
    }

    func suspendPrimaryWindowForLock() {
        guard let window, !isPrimaryWindowSuspendedForLock else { return }

        isPrimaryWindowSuspendedForLock = true
        notchViewModel.isLocked = true
        airDropController.resetTargetState()
        clearNowPlayingPrimaryWindowPresentationState()
        
        window.orderOut(nil)
    }

    func restorePrimaryWindowForUnlockTransition() {
        guard let window, isPrimaryWindowSuspendedForLock else { return }

        isPrimaryWindowSuspendedForLock = false
        notchViewModel.isLocked = false
        airDropController.resetTargetState()
        
        updateWindowFrame()
        reRegisterDragDestination(for: window)
    }

    func reRegisterDragDestination(for window: NSWindow) {
        let dragTypes: [NSPasteboard.PasteboardType] = [
            .fileURL,
            .URL,
            NSPasteboard.PasteboardType(UTType.data.identifier)
        ]

        func notifyViews(_ view: NSView) {
            if let dragView = view as? DragAndDropView {
                dragView.registerTypes()
            }
            for subview in view.subviews {
                notifyViews(subview)
            }
        }

        func performRegistration() {
            if let panel = window as? OverlayPanelWindow {
                panel.ensureFileDropRegistration(dragTypes)
            } else {
                window.registerForDraggedTypes(dragTypes)
            }
            if let contentView = window.contentView {
                notifyViews(contentView)
            }
        }

        // Immediate pass
        performRegistration()

        // Staggered passes to ensure WindowServer space transition has finished
        for delay in [0.2, 0.6, 1.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                performRegistration()
            }
        }
    }

    private func updatePrimaryWindowPresentation(on screen: NSScreen) {
        guard let window, !isPrimaryWindowSuspendedForLock else { return }

        let isFullscreen = SkyLightOperator.shared.isFullscreenSpaceActive(on: screen)
        let shouldHideActivities = settingsViewModel.application.isNotchHiddenInFullscreenEnabled && isFullscreen
        let shouldHideNotchlessIsland = screen.isNotchless && settingsViewModel.application.isDynamicIslandHiddenInFullscreenEnabled && isFullscreen

        notchViewModel.setActivityPresentationHidden(shouldHideActivities)

        if shouldHideActivities {
            clearNowPlayingPrimaryWindowPresentationState()
        }

        if shouldHideNotchlessIsland {
            if notchViewModel.hasDisplayedContent {
                hideWindowWorkItem?.cancel()
                hideWindowWorkItem = nil
                window.orderFrontRegardless()
            } else {
                scheduleDynamicIslandOrderOut()
            }
        } else {
            hideWindowWorkItem?.cancel()
            hideWindowWorkItem = nil
            window.orderFrontRegardless()
        }
    }

    private func scheduleDynamicIslandOrderOut() {
        guard hideWindowWorkItem == nil else { return }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  let screen = NSScreen.preferredNotchScreen(for: self.settingsViewModel),
                  screen.isNotchless,
                  SkyLightOperator.shared.isFullscreenSpaceActive(on: screen),
                  self.settingsViewModel.application.isDynamicIslandHiddenInFullscreenEnabled,
                  !self.notchViewModel.hasDisplayedContent else {
                return
            }
            self.window?.orderOut(nil)
            self.hideWindowWorkItem = nil
        }
        hideWindowWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
    }

    private func clearNowPlayingPrimaryWindowPresentationState() {
        nowPlayingViewModel.clearPresentationActivityState()
    }
}

/// A menu item that runs a closure.
final class NotchMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, symbol: String? = nil, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
        if let symbol { image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func run() { handler() }
}
