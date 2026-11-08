import Foundation

/// Ordered user-selectable pages; transient activities retain their own priority.
enum NotchPage: String, CaseIterable {
    case media, tray, mirror

    var contentID: String {
        switch self {
        case .media: return NotchContentRegistry.Media.nowPlaying.id
        case .tray: return NotchContentRegistry.DragAndDrop.trayActive.id
        case .mirror: return NotchContentRegistry.Mirror.preview.id
        }
    }

    static func from(contentID: String?) -> Self? {
        allCases.first { $0.contentID == contentID }
    }

    static func adjacent(to current: Self?, direction: NotchPageSwipe.Direction,
                         available: [Self]) -> Self? {
        guard !available.isEmpty else { return nil }
        guard let current, let index = available.firstIndex(of: current) else {
            return direction == .right ? available.first : available.last
        }
        let target = index + (direction == .right ? 1 : -1)
        return available.indices.contains(target) ? available[target] : nil
    }
}
