internal import AppKit
import Combine
import os
import SwiftUI

/// Stable payload shared by both hosts; playback ticks never replace their root views.
@MainActor
final class LockScreenPresentationSession: ObservableObject {
    @Published private(set) var snapshot: NowPlayingSnapshot?
    @Published private(set) var artworkImage: NSImage?
    func update(snapshot: NowPlayingSnapshot, artworkImage: NSImage?) {
        if self.snapshot != snapshot { self.snapshot = snapshot }
        if self.artworkImage !== artworkImage { self.artworkImage = artworkImage }
    }
}

@MainActor
final class LockScreenPanelAnimator: ObservableObject {
    enum Mode: String, CaseIterable {
        case compact, artwork, lyrics, lyricsWide
    }

    @Published var isPresented = false
    @Published private(set) var mode: Mode = .compact
    @Published var disablesTransitionAnimation = false
    @Published private(set) var retainsExpandedCanvas = false
    var prepareExpandedCanvas: (() -> Void)?
    static let transitionDuration = 0.5
    private var collapseTask: Task<Void, Never>?

    var showsLyrics: Bool { mode == .lyrics || mode == .lyricsWide }
    func toggleLyricsSize() {
        guard showsLyrics else { return }
        mode = mode == .lyricsWide ? .lyrics : .lyricsWide
    }
    var isArtworkExpanded: Bool { mode != .compact }
    func expandArtwork() {
        prepareExpandedCanvas?()
        collapseTask?.cancel(); retainsExpandedCanvas = false; mode = .artwork
    }
    func toggleLyrics() {
        prepareExpandedCanvas?()
        collapseTask?.cancel(); retainsExpandedCanvas = false; mode = showsLyrics ? .artwork : .lyrics
    }
    func presentImmediately() {
        guard !isPresented else { return }
        // Initial window presentation and user-initiated mode changes are independent.
        // Never let a nonanimated playback update disable subsequent transitions.
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction) { isPresented = true }
    }
    func closeExpandedPlayer() {
        guard mode != .compact else { return }
        collapseTask?.cancel()
        retainsExpandedCanvas = isPresented && !disablesTransitionAnimation && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        mode = .compact
        guard retainsExpandedCanvas else { return }
        collapseTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(600)) } catch { return }
            guard let self, self.mode == .compact else { return }
            self.retainsExpandedCanvas = false
        }
    }
    func disableLyrics() { if showsLyrics { mode = .artwork } }
}

@MainActor
final class LockScreenPanelManager {
    private let nowPlayingViewModel: NowPlayingViewModel
    private let lockScreenManager: LockScreenManager
    private let settingsViewModel: SettingsViewModel
    private let animator = LockScreenPanelAnimator()
    private let presentation = LockScreenPresentationSession()
    
    private let displayActivity = LockScreenDisplayActivity()
    private var panelWindow: OverlayPanelWindow?
    private var hostingView: NotchHostingView?
    private var foregroundContainer: NSView?
    private var backgroundWindow: OverlayPanelWindow?
    private var backgroundHostingView: NotchHostingView?
    private var hasDelegatedWindow = false
    private var recoveryTask: Task<Void, Never>?
    private var wasLocked = false
    private let logger = Logger(subsystem: "local.NotchFlow", category: "LockScreenMedia")
    private var appObservers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var cancellables = Set<AnyCancellable>()
    private var cachedSnapshot: NowPlayingSnapshot?
    private var cachedArtworkImage: NSImage?
    private var missingSessionWorkItem: DispatchWorkItem?
    private let missingSessionGracePeriod: TimeInterval = 5
    
    init(
        nowPlayingViewModel: NowPlayingViewModel,
        lockScreenManager: LockScreenManager,
        settingsViewModel: SettingsViewModel
    ) {
        self.nowPlayingViewModel = nowPlayingViewModel
        self.lockScreenManager = lockScreenManager
        self.settingsViewModel = settingsViewModel
        
        animator.prepareExpandedCanvas = { [weak self] in self?.prepareExpandedCanvas() }
        bindState()
        registerObservers()
    }
    
    func invalidate() {
        appObservers.forEach(NotificationCenter.default.removeObserver)
        appObservers.removeAll()
        
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach(workspaceCenter.removeObserver)
        workspaceObservers.removeAll()
        
        recoveryTask?.cancel()
        recoveryTask = nil
        cancellables.removeAll()
        releasePanelResources()
    }
    
    private func bindState() {
        animator.$retainsExpandedCanvas.removeDuplicates().dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.syncCurrentPresentation() }
            .store(in: &cancellables)
        animator.$mode.removeDuplicates().dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.syncCurrentPresentation() }
            .store(in: &cancellables)
        settingsViewModel.lockScreen.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.syncCurrentPresentation() }
            .store(in: &cancellables)
        LicenseStore.shared.$revision
            .dropFirst()
            .sink { [weak self] _ in self?.syncCurrentPresentation() }
            .store(in: &cancellables)
        Publishers.CombineLatest4(
            lockScreenManager.$isLocked.removeDuplicates(),
            lockScreenManager.$isPreparingLock.removeDuplicates(),
            nowPlayingViewModel.$snapshot,
            nowPlayingViewModel.$artworkImage
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] isLocked, isPreparingLock, liveSnapshot, artworkImage in
            self?.syncPlaybackPresentation(
                isLocked: isLocked,
                isPreparingLock: isPreparingLock,
                liveSnapshot: liveSnapshot,
                artworkImage: artworkImage
            )
        }
        .store(in: &cancellables)
        
        Publishers.CombineLatest3(
            settingsViewModel.application.$displayLocation.removeDuplicates(),
            settingsViewModel.application.$preferredDisplayUUID.removeDuplicates(),
            settingsViewModel.application.$isDisplayAutoSwitchEnabled.removeDuplicates()
        )
            .removeDuplicates(by: { lhs, rhs in
                lhs.0 == rhs.0 &&
                lhs.1 == rhs.1 &&
                lhs.2 == rhs.2
            })
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.recoverPresentation()
            }
            .store(in: &cancellables)
    }
    
    private func registerObservers() {
        appObservers.append(
            NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.recoverPresentation()
                }
            }
        )
        
        appObservers.append(
            NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.syncCurrentPresentation()
                }
            }
        )
        
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(
            workspaceCenter.addObserver(
                forName: NSWorkspace.screensDidWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.recoverPresentation()
                }
            }
        )
    }
    
    private func syncCurrentPresentation() {
        syncPlaybackPresentation(
            isLocked: lockScreenManager.isLocked,
            isPreparingLock: lockScreenManager.isPreparingLock,
            liveSnapshot: nowPlayingViewModel.snapshot,
            artworkImage: nowPlayingViewModel.artworkImage
        )
    }
    
    private func syncPlaybackPresentation(
        isLocked: Bool,
        isPreparingLock: Bool,
        liveSnapshot: NowPlayingSnapshot?,
        artworkImage: NSImage?
    ) {
        let isShowingLockPresentation = isLocked || isPreparingLock
        if isLocked && !wasLocked { scheduleRecovery() }
        wasLocked = isLocked
        if !isShowingLockPresentation {
            recoveryTask?.cancel()
            recoveryTask = nil
        }

        if let liveSnapshot {
            missingSessionWorkItem?.cancel()
            missingSessionWorkItem = nil
            cachedSnapshot = liveSnapshot
            cachedArtworkImage = artworkImage
        } else if !isShowingLockPresentation {
            missingSessionWorkItem?.cancel()
            missingSessionWorkItem = nil
            cachedSnapshot = nil
            cachedArtworkImage = nil
        } else if cachedSnapshot != nil && missingSessionWorkItem == nil {
            // Media providers can briefly lose the session during the lock transition.
            // Do not keep stale song information indefinitely if the session ends.
            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.missingSessionWorkItem = nil
                guard self.nowPlayingViewModel.snapshot == nil else { return }
                self.cachedSnapshot = nil
                self.cachedArtworkImage = nil
                self.syncCurrentPresentation()
            }
            missingSessionWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + missingSessionGracePeriod, execute: workItem)
        }
        
        let resolvedSnapshot = resolvedSnapshot(
            isShowingLockPresentation: isShowingLockPresentation,
            liveSnapshot: liveSnapshot
        )
        let resolvedArtworkImage = resolvedArtworkImage(
            isShowingLockPresentation: isShowingLockPresentation,
            liveSnapshot: liveSnapshot,
            artworkImage: artworkImage
        )
        
        updatePresentation(
            isShowingLockPresentation: isShowingLockPresentation,
            snapshot: resolvedSnapshot,
            artworkImage: resolvedArtworkImage
        )
    }
    
    private func updatePresentation(
        isShowingLockPresentation: Bool,
        snapshot: NowPlayingSnapshot?,
        artworkImage: NSImage?
    ) {
        guard LicenseStore.shared.hasPro, LockScreenSettings.isMediaPanelEnabled() else {
            hidePanel(animated: true, releaseResources: true)
            return
        }
        
        if isShowingLockPresentation, let snapshot {
            showPanel(snapshot: snapshot, artworkImage: artworkImage, animated: false)
        } else {
            hidePanel(animated: true, releaseResources: true)
        }
    }
    
    private func showPanel(
        snapshot: NowPlayingSnapshot,
        artworkImage: NSImage?,
        animated: Bool
    ) {
        guard let screen = currentScreen() else {
            releasePanelResources()
            return
        }
        
        let window = makeWindowIfNeeded(for: screen)
        let background = makeBackgroundWindowIfNeeded(for: screen)
        let targetFrame = panelFrame(for: screen)
        presentation.update(snapshot: snapshot, artworkImage: artworkImage)
        let rootView = LockScreenNowPlayingPanelView(
            snapshot: snapshot,
            artworkImage: artworkImage,
            screen: screen,
            settingsViewModel: settingsViewModel,
            nowPlayingViewModel: nowPlayingViewModel,
            lockScreenManager: lockScreenManager,
            animator: animator,
            presentation: presentation
        )
        
        let region = foregroundRegion(for: screen)
        let foregroundFrame = NSRect(x: targetFrame.minX + region.minX,
                                     y: targetFrame.maxY - region.maxY,
                                     width: region.width, height: region.height)
        if window.frame != foregroundFrame { window.setFrame(foregroundFrame, display: true) }
        if background.frame != targetFrame {
            background.setFrame(targetFrame, display: true)
        }
        let backgroundView = LockScreenMediaBackgroundView(artworkImage: artworkImage,
                                                           settingsViewModel: settingsViewModel,
                                                           nowPlayingViewModel: nowPlayingViewModel,
                                                           animator: animator, presentation: presentation)
        if let backgroundHostingView {
            backgroundHostingView.frame = NSRect(origin: .zero, size: targetFrame.size)
        } else {
            let view = NotchHostingView(rootView: backgroundView)
            view.frame = NSRect(origin: .zero, size: targetFrame.size)
            view.autoresizingMask = [.width, .height]
            backgroundHostingView = view
            background.contentView = view
        }
        
        if hostingView == nil {
            let view = NotchHostingView(rootView: rootView)
            self.hostingView = view
            let container = NSView(frame: NSRect(origin: .zero, size: foregroundFrame.size))
            container.addSubview(view)
            foregroundContainer = container
            window.contentView = container
        }
        foregroundContainer?.frame = NSRect(origin: .zero, size: foregroundFrame.size)
        // Keep full-screen SwiftUI geometry inside a window sized to visible controls.
        hostingView?.frame = NSRect(x: -region.minX, y: -(targetFrame.height - region.maxY),
                                    width: targetFrame.width, height: targetFrame.height)
        
        // AppKit must register/order the windows before SkyLight can adopt their IDs.
        if !hasDelegatedWindow || !background.isVisible || !window.isVisible {
            background.orderFrontRegardless()
            window.orderFrontRegardless()
        }

        if !hasDelegatedWindow {
            guard SkyLightOperator.shared.delegateWindow(background, to: .lockScreenOverlay),
                  SkyLightOperator.shared.delegateWindow(window, to: .lockScreenOverlay) else {
                logger.error("Cannot attach media windows to lock-screen space; retrying during lock transition")
                releasePanelResources()
                return
            }
            hasDelegatedWindow = true
            Task { [weak self, weak window, weak background] in
                try? await Task.sleep(for: .milliseconds(120))
                guard let self, let window, let background, self.panelWindow === window else { return }
                let foreground = SkyLightOperator.shared.isWindowDelegated(window, to: .lockScreenOverlay)
                let backdrop = SkyLightOperator.shared.isWindowDelegated(background, to: .lockScreenOverlay)
                self.logger.notice("Lock media submitted: locked=\(self.lockScreenManager.isLocked), foregroundMember=\(String(describing: foreground), privacy: .public), backdropMember=\(String(describing: backdrop), privacy: .public)")
            }
        }
        
        displayActivity.setActive(lockScreenManager.isLocked && window.isVisible && settingsViewModel.lockScreen.keepDisplayAwake)
        guard animated else {
            animator.presentImmediately()
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.animator.isPresented = true
        }
    }
    
    private func hidePanel(animated: Bool, releaseResources: Bool = false) {
        displayActivity.setActive(false)
        animator.isPresented = false
        animator.closeExpandedPlayer()
        
        guard let window = panelWindow else {
            if releaseResources {
                releasePanelResources()
            }
            return
        }
        
        if lockScreenManager.didUnlockWithFaceID {
            window.orderOut(nil)
            backgroundWindow?.orderOut(nil)
            if releaseResources {
                releasePanelResources()
            }
            return
        }

        let delay = animated ? 0.22 : 0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak window] in
            guard let self else { return }
            
            let shouldRemainVisible =
            self.lockScreenManager.isShowingLockPresentation &&
            self.resolvedSnapshot(
                isShowingLockPresentation: self.lockScreenManager.isShowingLockPresentation,
                liveSnapshot: self.nowPlayingViewModel.snapshot
            ) != nil &&
            LockScreenSettings.isMediaPanelEnabled() && LicenseStore.shared.hasPro
            
            guard !shouldRemainVisible else { return }
            
            window?.orderOut(nil)
            self.backgroundWindow?.orderOut(nil)

            if releaseResources {
                self.releasePanelResources()
            }
        }
    }

    private func releasePanelResources() {
        displayActivity.setActive(false)
        animator.closeExpandedPlayer()
        missingSessionWorkItem?.cancel()
        missingSessionWorkItem = nil
        cachedSnapshot = nil
        cachedArtworkImage = nil
        animator.isPresented = false

        panelWindow?.orderOut(nil)
        panelWindow?.contentView = nil
        hostingView = nil
        foregroundContainer = nil
        panelWindow = nil
        backgroundWindow?.orderOut(nil)
        backgroundWindow?.contentView = nil
        backgroundHostingView = nil
        backgroundWindow = nil
        hasDelegatedWindow = false
    }
    
    private func recoverPresentation() {
        hasDelegatedWindow = false
        syncCurrentPresentation()
        if lockScreenManager.isShowingLockPresentation { scheduleRecovery() }
    }

    private func scheduleRecovery() {
        recoveryTask?.cancel()
        recoveryTask = Task { [weak self] in
            // Bounded reattachment: loginwindow rebuilds its shield asynchronously.
            for delay in [0.15, 0.35, 0.75, 1.25] {
                do { try await Task.sleep(for: .seconds(delay)) } catch { return }
                guard let self, self.lockScreenManager.isShowingLockPresentation,
                      LicenseStore.shared.hasPro, LockScreenSettings.isMediaPanelEnabled() else { return }
                self.hasDelegatedWindow = false
                self.syncCurrentPresentation()
            }
        }
    }

    private func prepareExpandedCanvas() {
        guard let screen = currentScreen(), let window = panelWindow else { return }
        let frame = panelFrame(for: screen)
        // Resize the transparent AppKit canvas before SwiftUI begins moving the cover.
        window.setFrame(frame, display: false)
        foregroundContainer?.frame = NSRect(origin: .zero, size: frame.size)
        hostingView?.frame = NSRect(origin: .zero, size: frame.size)
    }

    private func foregroundRegion(for screen: NSScreen) -> CGRect {
        LockScreenMediaLayout(screenSize: panelFrame(for: screen).size,
                              showsLyrics: animator.showsLyrics && settingsViewModel.lockScreen.isLockScreenLyricsEnabled)
            .foregroundFrame(isExpanded: animator.isArtworkExpanded || animator.retainsExpandedCanvas,
                             verticalOffset: settingsViewModel.lockScreen.mediaPanelVerticalOffset)
    }

    private func resolvedSnapshot(
        isShowingLockPresentation: Bool,
        liveSnapshot: NowPlayingSnapshot?
    ) -> NowPlayingSnapshot? {
        liveSnapshot ?? (isShowingLockPresentation ? cachedSnapshot : nil)
    }
    
    private func resolvedArtworkImage(
        isShowingLockPresentation: Bool,
        liveSnapshot: NowPlayingSnapshot?,
        artworkImage: NSImage?
    ) -> NSImage? {
        if liveSnapshot != nil {
            return artworkImage
        }
        
        return isShowingLockPresentation ? cachedArtworkImage : nil
    }
    
    private func makeWindowIfNeeded(for screen: NSScreen) -> OverlayPanelWindow {
        if let panelWindow {
            return panelWindow
        }

        let window = OverlayPanelFactory.makeLockScreenPanel(frame: panelFrame(for: screen))

        panelWindow = window
        return window
    }

    private func makeBackgroundWindowIfNeeded(for screen: NSScreen) -> OverlayPanelWindow {
        if let backgroundWindow { return backgroundWindow }
        let window = OverlayPanelFactory.makeLockScreenBackground(frame: panelFrame(for: screen))
        backgroundWindow = window
        return window
    }
    
    private func currentScreen() -> NSScreen? {
        NSScreen.preferredLockScreen ??
        NSScreen.preferredNotchScreen(for: settingsViewModel) ??
        NSScreen.main ??
        NSScreen.screens.first
    }
    
    private func panelFrame(for screen: NSScreen) -> NSRect {
        OverlayWindowLayout.lockScreenCanvasFrame(on: screen)
    }
}
