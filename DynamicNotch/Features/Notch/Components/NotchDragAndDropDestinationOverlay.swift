import SwiftUI

struct NotchDragAndDropDestinationOverlay: View {
    var isShowingTrayPage = false
    @ObservedObject private var license = LicenseStore.shared
    private var availableMode: DragAndDropActivityMode? {
        guard settingsViewModel.isLiveActivityEnabled(.drop) else { return nil }
        return .available(preferred: settingsViewModel.mediaAndFiles.dragAndDropActivityMode,
                          airDrop: settingsViewModel.mediaAndFiles.isAirDropLiveActivityEnabled,
                          tray: settingsViewModel.mediaAndFiles.isTrayLiveActivityEnabled && license.hasPro,
                          showingTray: isShowingTrayPage)
    }
    @ObservedObject var airDropViewModel: AirDropNotchViewModel
    @ObservedObject var airDropController: NotchAirDropController
    @ObservedObject var settingsViewModel: SettingsViewModel
    
    var body: some View {
        DragAndDropDestinationView(
            isTargeted: $airDropController.isTargeted,
            targetedDropTarget: Binding(
                get: { airDropViewModel.targetedDropTarget },
                set: { airDropViewModel.setTargetedDropTarget($0) }
            ),
            mode: availableMode ?? .airDrop,
            isEnabled: availableMode != nil,
            onDropPasteboard: { target, pasteboard in
                switch target {
                case .airDrop:
                    guard availableMode?.showsAirDrop == true,
                          settingsViewModel.mediaAndFiles.isAirDropLiveActivityEnabled else {
                        return false
                    }
                    
                    return airDropController.handlePasteboardDrop(pasteboard)
                case .tray:
                    guard availableMode?.showsTray == true,
                          settingsViewModel.mediaAndFiles.isTrayLiveActivityEnabled else {
                        return false
                    }
                    
                    return airDropController.handleTrayDrop(
                        pasteboard,
                        mode: settingsViewModel.mediaAndFiles.fileTrayUsageMode
                    )
                }
            }
        )
    }
}
