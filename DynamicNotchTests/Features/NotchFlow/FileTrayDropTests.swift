import XCTest
import AppKit
@testable import DynamicNotch

@MainActor
final class FileTrayDropTests: XCTestCase {
    func testDestinationCoversWholeNotchAndMatchesVisibleSide() {
        for size in [NSSize(width: 190, height: 38), NSSize(width: 480, height: 160)] {
            let bounds = NSRect(origin: .zero, size: size)
            for y in [CGFloat(1), size.height / 2, size.height - 1] {
                XCTAssertEqual(DragAndDropView.target(at: NSPoint(x: 1, y: y), in: bounds, mode: .combined), .airDrop)
                XCTAssertEqual(DragAndDropView.target(at: NSPoint(x: size.width - 1, y: y), in: bounds, mode: .combined), .tray)
                XCTAssertEqual(DragAndDropView.target(at: NSPoint(x: 1, y: y), in: bounds, mode: .tray), .tray)
            }
            XCTAssertNil(DragAndDropView.target(at: NSPoint(x: -1, y: 3), in: bounds, mode: .combined))
        }
    }

    func testAvailabilityMatchesEnabledAndLicensedZones() {
        XCTAssertNil(DragAndDropActivityMode.available(preferred: .combined, airDrop: false, tray: false))
        XCTAssertEqual(DragAndDropActivityMode.available(preferred: .combined, airDrop: true, tray: false), .airDrop)
        XCTAssertEqual(DragAndDropActivityMode.available(preferred: .airDrop, airDrop: false, tray: true), .tray)
        XCTAssertEqual(DragAndDropActivityMode.available(preferred: .combined, airDrop: true, tray: true), .combined)
        XCTAssertEqual(DragAndDropActivityMode.available(preferred: .combined, airDrop: true, tray: true, showingTray: true), .tray)
    }

    func testWindowForwardsDropAndDoesNotInterceptPointerEvents() throws {
        let panel = OverlayPanelFactory.makePanel(frame: NSRect(x: 0, y: 0, width: 400, height: 220), level: .normal)
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 220))
        panel.contentView = container
        let view = DragAndDropView(frame: NSRect(x: 50, y: 50, width: 240, height: 120))
        view.mode = .combined
        container.addSubview(view)
        defer { panel.contentView = nil; panel.close() }
        XCTAssertTrue(panel.fileDropDestination === view)
        XCTAssertNil(view.hitTest(NSPoint(x: 100, y: 100)))
        let types = Set(view.registeredDraggedTypes)
        view.registerTypes(); view.registerTypes()
        XCTAssertEqual(types, Set(view.registeredDraggedTypes))
        let board = NSPasteboard(name: .init("notchflow.test." + UUID().uuidString))
        defer { board.releaseGlobally() }
        board.declareTypes([.fileURL], owner: nil)
        XCTAssertTrue(board.setString(URL(fileURLWithPath: "/tmp/test.txt").absoluteString, forType: .fileURL))
        let drag = FakeNotchDraggingInfo(window: panel, pasteboard: board, location: NSPoint(x: 255, y: 100))
        var dropped: DragAndDropTarget?
        view.onDropPasteboard = { target, _ in dropped = target; return true }
        XCTAssertEqual(panel.draggingEntered(drag), .copy)
        XCTAssertTrue(panel.prepareForDragOperation(drag))
        XCTAssertTrue(panel.performDragOperation(drag))
        XCTAssertEqual(dropped, .tray)
        drag.location = NSPoint(x: 10, y: 10)
        XCTAssertEqual(panel.draggingUpdated(drag), [])
        drag.location = NSPoint(x: 255, y: 100)
        view.isDropEnabled = false
        XCTAssertEqual(panel.draggingEntered(drag), [])
        view.isDropEnabled = true
        board.addTypes([FileTrayPasteboard.localDragPasteboardType], owner: nil)
        board.setData(Data([1]), forType: FileTrayPasteboard.localDragPasteboardType)
        XCTAssertEqual(panel.draggingEntered(drag), [], "Dragging an item out must not re-import it")
    }

    func testTrayItemHitTestingUsesSuperviewCoordinates() {
        let parent = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 200))
        let item = TrayExpandedItemDragNSView(frame: NSRect(x: 100, y: 40, width: 80, height: 94))
        parent.addSubview(item)
        XCTAssertNotNil(item.hitTest(NSPoint(x: 120, y: 70)))
        XCTAssertNil(item.hitTest(NSPoint(x: 170, y: 125)), "The close button must remain clickable")
        item.showsRemoveButton = false
        XCTAssertNotNil(item.hitTest(NSPoint(x: 170, y: 125)), "The full item should be draggable when remove is hidden")
    }

    func testCopyImportAndRemovalLeaveOriginalsIntact() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("NotchFlowTrayTest-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source1 = root.appendingPathComponent("first.txt"), source2 = root.appendingPathComponent("second.txt")
        try Data("first".utf8).write(to: source1); try Data("second".utf8).write(to: source2)
        let suite = "NotchFlow.TrayTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = FileTrayViewModel(defaults: defaults, storageRootURL: root.appendingPathComponent("stored"))
        try model.add([source1, source2], mode: .copy)
        XCTAssertEqual(model.items.count, 2)
        XCTAssertEqual(try Data(contentsOf: model.items[0].url), Data("first".utf8))
        model.clear()
        XCTAssertEqual(try Data(contentsOf: source1), Data("first".utf8))
        XCTAssertEqual(try Data(contentsOf: source2), Data("second".utf8))
    }

    func testFailedBatchMoveReturnsFirstOriginal() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("NotchFlowTrayRollback-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("document.txt")
        try Data("do not lose".utf8).write(to: source)
        let suite = "NotchFlow.TrayTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let storage = root.appendingPathComponent("stored")
        let model = FileTrayViewModel(defaults: defaults, storageRootURL: storage)
        XCTAssertThrowsError(try model.add([source, source], mode: .moveOriginals))
        XCTAssertTrue(model.items.isEmpty)
        XCTAssertEqual(try Data(contentsOf: source), Data("do not lose".utf8))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: storage.path), [])
    }
}

private final class FakeNotchDraggingInfo: NSObject, NSDraggingInfo {
    let draggingDestinationWindow: NSWindow?
    let draggingPasteboard: NSPasteboard
    var location: NSPoint
    init(window: NSWindow, pasteboard: NSPasteboard, location: NSPoint) {
        draggingDestinationWindow = window; draggingPasteboard = pasteboard; self.location = location
    }
    var draggingLocation: NSPoint { location }
    var draggingSourceOperationMask: NSDragOperation { [.copy, .move] }
    var draggedImageLocation: NSPoint { .zero }
    var draggedImage: NSImage? { nil }
    var draggingSource: Any? { nil }
    var draggingSequenceNumber: Int { 1 }
    var draggingFormation: NSDraggingFormation = .default
    var animatesToDestination = false
    var numberOfValidItemsForDrop = 1
    var springLoadingHighlight: NSSpringLoadingHighlight { .none }
    func slideDraggedImage(to screenPoint: NSPoint) {}
    func enumerateDraggingItems(options: NSDraggingItemEnumerationOptions, for view: NSView?, classes classArray: [AnyClass],
                                searchOptions: [NSPasteboard.ReadingOptionKey: Any],
                                using block: @escaping (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void) {}
    func resetSpringLoading() {}
}
