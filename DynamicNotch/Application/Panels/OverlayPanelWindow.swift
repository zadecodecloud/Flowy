internal import AppKit

final class OverlayPanelWindow: NSPanel {
    var allowsKeyWindow: Bool = true
    var allowsMainWindow: Bool = true
    weak var fileDropDestination: DragAndDropView?
    private var fileDropTypes = Set<NSPasteboard.PasteboardType>()

    func ensureFileDropRegistration(_ types: [NSPasteboard.PasteboardType]) {
        let wanted = Set(types)
        guard wanted != fileDropTypes else { return }
        registerForDraggedTypes(types)
        fileDropTypes = wanted
    }

    // The SwiftUI overlay deliberately passes pointer events through. Forward
    // the window's drag callbacks directly so a stale mouse event cannot hide
    // the drop destination from a drag coming from Finder.
    @objc func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        fileDropDestination?.draggingEntered(sender) ?? []
    }
    @objc func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        fileDropDestination?.draggingUpdated(sender) ?? []
    }
    @objc func draggingExited(_ sender: NSDraggingInfo?) {
        fileDropDestination?.draggingExited(sender)
    }
    @objc func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        fileDropDestination?.prepareForDragOperation(sender) ?? false
    }
    @objc func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        fileDropDestination?.performDragOperation(sender) ?? false
    }
    @objc func concludeDragOperation(_ sender: NSDraggingInfo?) {
        fileDropDestination?.concludeDragOperation(sender)
    }

    override var canBecomeKey: Bool { allowsKeyWindow }
    override var canBecomeMain: Bool { allowsMainWindow }
    override var isKeyWindow: Bool { allowsKeyWindow }
    override var isMainWindow: Bool { allowsMainWindow }
}
