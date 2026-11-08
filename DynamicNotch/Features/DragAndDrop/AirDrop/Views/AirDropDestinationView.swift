//
//  AirDropDestinationView.swift
//  DynamicNotch
//
//  Created by Евгений Петрукович on 3/24/26.
//

import SwiftUI
import UniformTypeIdentifiers
internal import AppKit

struct DragAndDropDestinationView: NSViewRepresentable {
    @Binding var isTargeted: Bool
    @Binding var targetedDropTarget: DragAndDropTarget?
    
    let mode: DragAndDropActivityMode
    var isEnabled = true
    let onDropPasteboard: (DragAndDropTarget, NSPasteboard) -> Bool

    func makeNSView(context: Context) -> DragAndDropView {
        let view = DragAndDropView()
        view.mode = mode
        view.isDropEnabled = isEnabled
        view.onTargetedChange = { isTargeted in
            DispatchQueue.main.async {
                self.isTargeted = isTargeted
            }
        }
        view.onTargetedDropTargetChange = { target in
            DispatchQueue.main.async {
                self.targetedDropTarget = target
            }
        }
        view.onDropPasteboard = onDropPasteboard
        return view
    }

    func updateNSView(_ nsView: DragAndDropView, context: Context) {
        nsView.mode = mode
        nsView.isDropEnabled = isEnabled
        nsView.onTargetedChange = { isTargeted in
            DispatchQueue.main.async {
                self.isTargeted = isTargeted
            }
        }
        nsView.onTargetedDropTargetChange = { target in
            DispatchQueue.main.async {
                self.targetedDropTarget = target
            }
        }
        nsView.onDropPasteboard = onDropPasteboard
        nsView.registerTypes()
    }
}

final class DragAndDropView: NSView {
    var mode: DragAndDropActivityMode = .airDrop
    var isDropEnabled = true
    var onTargetedChange: (Bool) -> Void = { _ in }
    var onTargetedDropTargetChange: (DragAndDropTarget?) -> Void = { _ in }
    var onDropPasteboard: (DragAndDropTarget, NSPasteboard) -> Bool = { _, _ in false }

    private var workspaceObserver: NSObjectProtocol?
    private var screenUnlockObserver: NSObjectProtocol?
    private weak var registeredWindow: OverlayPanelWindow?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerTypes()
        setupNotificationObservers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        removeNotificationObservers()
    }

    func registerTypes() {
        let dragTypes: [NSPasteboard.PasteboardType] = [
            .fileURL,
            .URL,
            NSPasteboard.PasteboardType(UTType.data.identifier)
        ]
        // SwiftUI updates this view as the drag highlights change. Re-registering
        // during a live session can make WindowServer discard that destination.
        if Set(registeredDraggedTypes) != Set(dragTypes) {
            registerForDraggedTypes(dragTypes)
        }
        (window as? OverlayPanelWindow)?.ensureFileDropRegistration(dragTypes)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if registeredWindow !== window, registeredWindow?.fileDropDestination === self {
            registeredWindow?.fileDropDestination = nil
        }
        registeredWindow = window as? OverlayPanelWindow
        registeredWindow?.fileDropDestination = self
        if window != nil { registerTypes() }
    }

    private func setupNotificationObservers() {
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.registerTypes()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.registerTypes()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self?.registerTypes()
            }
        }

        screenUnlockObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.registerTypes()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.registerTypes()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self?.registerTypes()
            }
        }
    }

    private func removeNotificationObservers() {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            workspaceObserver = nil
        }
        if let observer = screenUnlockObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            screenUnlockObserver = nil
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard isDropEnabled, containsDragLocation(sender),
              sender.draggingPasteboard.isFileTrayLocalDrag == false,
              sender.draggingPasteboard.containsAirDropFiles else {
            onTargetedChange(false)
            onTargetedDropTargetChange(nil)
            return []
        }

        onTargetedChange(true)
        let target = dropTarget(for: sender)
        onTargetedDropTargetChange(target)
        return target?.acceptsDrop == true ? .copy : []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard isDropEnabled, containsDragLocation(sender),
              sender.draggingPasteboard.isFileTrayLocalDrag == false,
              sender.draggingPasteboard.containsAirDropFiles else {
            onTargetedChange(false)
            onTargetedDropTargetChange(nil)
            return []
        }

        onTargetedChange(true)
        let target = dropTarget(for: sender)
        onTargetedDropTargetChange(target)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onTargetedChange(false)
        onTargetedDropTargetChange(nil)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isDropEnabled && containsDragLocation(sender) &&
        sender.draggingPasteboard.isFileTrayLocalDrag == false &&
        sender.draggingPasteboard.containsAirDropFiles &&
        dropTarget(for: sender)?.acceptsDrop == true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard isDropEnabled, containsDragLocation(sender),
              sender.draggingPasteboard.isFileTrayLocalDrag == false,
              sender.draggingPasteboard.containsAirDropFiles,
              let target = dropTarget(for: sender) else {
            onTargetedDropTargetChange(nil)
            return false
        }

        let result = onDropPasteboard(target, sender.draggingPasteboard)
        onTargetedChange(false)
        onTargetedDropTargetChange(nil)
        return result
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        onTargetedChange(false)
        onTargetedDropTargetChange(nil)
    }

    private func dropTarget(for sender: NSDraggingInfo) -> DragAndDropTarget? {
        let location = convert(sender.draggingLocation, from: nil)
        return Self.target(at: location, in: bounds, mode: mode)
    }

    /// Match the visible left/right order, while making the entire notch usable.
    static func target(at point: NSPoint, in bounds: NSRect, mode: DragAndDropActivityMode) -> DragAndDropTarget? {
        guard bounds.contains(point) else { return nil }
        if mode.targets.count == 1 { return mode.targets.first }
        return point.x < bounds.midX ? .airDrop : .tray
    }

    private func containsDragLocation(_ sender: NSDraggingInfo) -> Bool {
        !isHiddenOrHasHiddenAncestor && bounds.contains(convert(sender.draggingLocation, from: nil))
    }

}
