import SwiftUI

/// One spacing rule for every expanded notch page, on Apple's 8-pt grid.
///
/// `NotchShape` flares into concave shoulders at the top, so the visible body is narrower
/// than the content frame by `topCornerRadius` on each side. Insetting by that radius plus
/// `innerMargin` keeps every page the same distance from the notch walls.
enum NotchPageMetrics {
    static let innerMargin: CGFloat = 20
    static let notchlessHorizontalPadding: CGFloat = 20
    static let blockSpacing: CGFloat = 12
    /// Shared corner radii of the expanded pages (Music keeps its wider 34 pt shoulders).
    static let topCornerRadius: CGFloat = 24
    static let bottomCornerRadius: CGFloat = 28
    /// Space from the top of the frame to the first line of content: clears the camera band.
    static let topPadding: CGFloat = 24
    static let notchlessTopPadding: CGFloat = 8

    static var cornerRadius: (top: CGFloat, bottom: CGFloat) { (topCornerRadius, bottomCornerRadius) }

    static func horizontalPadding(topCornerRadius: CGFloat, isNotchless: Bool) -> CGFloat {
        isNotchless ? notchlessHorizontalPadding : topCornerRadius + innerMargin
    }
}

extension View {
    /// The standard top and side insets of an expanded notch page.
    func notchPagePadding(isNotchless: Bool,
                          topCornerRadius: CGFloat = NotchPageMetrics.topCornerRadius) -> some View {
        padding(.top, isNotchless ? NotchPageMetrics.notchlessTopPadding : NotchPageMetrics.topPadding)
            .padding(.horizontal, NotchPageMetrics.horizontalPadding(topCornerRadius: topCornerRadius,
                                                                     isNotchless: isNotchless))
    }
}
