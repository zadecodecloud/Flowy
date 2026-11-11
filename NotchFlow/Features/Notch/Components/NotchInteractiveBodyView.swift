import SwiftUI
internal import AppKit

struct NotchInteractiveBodyView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onPageSwipe: (NotchPageSwipe.Direction) -> Void = { _ in }
    var onPageSelect: (NotchPage) -> Void = { _ in }
    @ObservedObject var notchViewModel: NotchViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel
    
    var body: some View {
        NotchSurfaceContainerView(
            notchViewModel: notchViewModel,
            settingsViewModel: settingsViewModel
        )
        .opacity(isVisiblyHiddenInFullscreen ? 0 : 1)
        .frame(
            width: notchViewModel.presentedNotchSize.width,
            height: notchViewModel.presentedNotchSize.height,
            alignment: .top
        )
        // Press, hold, hover, mouse-drag dismiss and the right-click menu are handled by
        // `NotchShellInputController` (clicks do not reliably reach this window).
        .customNotchSwipeDismissable(
            notchViewModel: notchViewModel,
            isEnabled: shouldEnableNotchSwipeGestures
        )
        .background(NotchPageSwipeMonitor(isEnabled: !isVisiblyHiddenInFullscreen && !notchViewModel.isLocked,
                    onSwipe: onPageSwipe))
        .offset(y: notchViewModel.isDynamicIsland ? 9 : 1)
        .environment(\.colorScheme, .dark)
        .animation(notchViewModel.animations.strokeVisibility, value: notchViewModel.shouldRenderStroke)
        .animation(notchViewModel.animations.strokeVisibility, value: settingsViewModel.isShowNotchStrokeEnabled)
        .transaction { transaction in
            if reduceMotion { transaction.animation = nil }
        }
    }
    
    private var isVisiblyHiddenInFullscreen: Bool {
        guard notchViewModel.isDynamicIsland else { return false }
        guard settingsViewModel.application.isDynamicIslandHiddenInFullscreenEnabled else { return false }
        guard let screen = NSScreen.preferredNotchScreen(for: settingsViewModel) ?? NSScreen.main else { return false }
        return SkyLightOperator.shared.isFullscreenSpaceActive(on: screen) && !notchViewModel.hasDisplayedContent
    }
    
    private var shouldEnableNotchSwipeGestures: Bool {
        guard (!notchViewModel.isActivityPresentationHidden || notchViewModel.isLocked) || notchViewModel.notchModel.temporaryNotificationContent != nil else { return false }
        
        return !(
            notchViewModel.isDisplayingExpandedLiveActivity &&
            notchViewModel.displayedContent?.id == NotchContentRegistry.DragAndDrop.trayActive.id
        )
    }
}
