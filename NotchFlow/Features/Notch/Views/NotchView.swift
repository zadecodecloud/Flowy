import SwiftUI
import Combine
internal import AppKit
import UniformTypeIdentifiers

struct NotchView: View {
    let notchEventCoordinator: NotchEventCoordinator
    
    @ObservedObject var notchViewModel: NotchViewModel
    @ObservedObject var airDropViewModel: AirDropNotchViewModel
    @ObservedObject var airDropController: NotchAirDropController
    @ObservedObject var settingsViewModel: SettingsViewModel
    
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        NotchInteractiveBodyView(
            onPageSwipe: notchEventCoordinator.switchNotchPage,
            onPageSelect: notchEventCoordinator.openPage,
            notchViewModel: notchViewModel,
            settingsViewModel: settingsViewModel
        )
        .overlay(alignment: .top) {
            NotchPageIndicator(
                pages: notchEventCoordinator.availablePages,
                current: NotchPage.from(contentID: notchViewModel.displayedContent?.id),
                isExpanded: notchViewModel.isDisplayingExpandedLiveActivity,
                notchWidth: notchViewModel.presentedNotchSize.width,
                cameraBandWidth: notchViewModel.notchModel.baseWidth,
                bandHeight: notchViewModel.notchModel.baseHeight,
                topCornerRadius: notchViewModel.interactiveCornerRadius.top
            )
        }
        .environment(\.notchScale, notchViewModel.notchModel.scale)
        .environment(\.locale, settingsViewModel.application.notchLanguage.effectiveNotchLanguage.locale)
        .overlay {
            NotchDragAndDropDestinationOverlay(
                isShowingTrayPage: notchViewModel.displayedContent?.id == NotchContentRegistry.DragAndDrop.trayActive.id,
                airDropViewModel: airDropViewModel,
                airDropController: airDropController,
                settingsViewModel: settingsViewModel
            )
        }
        .onChange(of: notchViewModel.displayedContent?.id) {
            notchViewModel.handleStrokeVisibility()
        }
        .onChange(of: settingsViewModel.application.notchWidth) { _, _ in
            notchViewModel.updateDimensions()
        }
        .onChange(of: settingsViewModel.application.notchHeight) { _, _ in
            notchViewModel.updateDimensions()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
