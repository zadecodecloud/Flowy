import SwiftUI

enum DragAndDropActivityMode: String, CaseIterable {
    case airDrop
    case tray
    case combined

    var title: LocalizedStringKey {
        switch self {
        case .airDrop:
            return "settings.drop.dragAndDropActivityMode.airDrop"
        case .tray:
            return "settings.drop.dragAndDropActivityMode.tray"
        case .combined:
            return "settings.drop.dragAndDropActivityMode.both"
        }
    }

    var targets: [DragAndDropTarget] {
        switch self {
        case .airDrop:
            return [.airDrop]
        case .tray:
            return [.tray]
        case .combined:
            return [.airDrop, .tray]
        }
    }

    var showsAirDrop: Bool {
        targets.contains(.airDrop)
    }

    var showsTray: Bool {
        targets.contains(.tray)
    }

    /// The displayed zones and the destination must use the same enabled targets.
    static func available(preferred: Self, airDrop: Bool, tray: Bool, showingTray: Bool = false) -> Self? {
        if showingTray, tray { return .tray }
        switch (airDrop, tray) {
        case (false, false): return nil
        case (true, false): return .airDrop
        case (false, true): return .tray
        case (true, true): return preferred
        }
    }

    static func resolved(_ rawValue: String?) -> DragAndDropActivityMode {
        switch rawValue {
        case DragAndDropActivityMode.tray.rawValue:
            return .tray
        case DragAndDropActivityMode.combined.rawValue:
            return .combined
        default:
            return .combined
        }
    }
}
