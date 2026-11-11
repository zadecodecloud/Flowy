import SwiftUI

/// Page name (left wing) and page dots (right wing) in the black band beside the camera.
/// Always visible while an expanded page has siblings. Shared by every swipeable page so
/// new pages get the same indicator without adding chrome to their own layouts.
struct NotchPageIndicator: View {
    let pages: [NotchPage]
    let current: NotchPage?
    let isExpanded: Bool
    let notchWidth: CGFloat
    let cameraBandWidth: CGFloat
    let bandHeight: CGFloat
    let topCornerRadius: CGFloat

    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static func wingWidth(notchWidth: CGFloat, cameraBandWidth: CGFloat, topCornerRadius: CGFloat) -> CGFloat {
        max(0, (notchWidth - cameraBandWidth) / 2 - topCornerRadius - 8)
    }

    static func isShown(pages: [NotchPage], current: NotchPage?, isExpanded: Bool) -> Bool {
        isExpanded && current != nil && pages.count > 1
    }

    var body: some View {
        let wing = Self.wingWidth(notchWidth: notchWidth, cameraBandWidth: cameraBandWidth,
                                  topCornerRadius: topCornerRadius)
        let shown = Self.isShown(pages: pages, current: current, isExpanded: isExpanded)
        HStack(spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: wing, alignment: .leading)
            Spacer(minLength: 0)
            dots
                .frame(width: wing, alignment: .trailing)
        }
        .padding(.horizontal, topCornerRadius + 4)
        .frame(width: notchWidth, height: bandHeight)
        .opacity(shown ? 1 : 0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: shown)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityIdentifier("notch.pageIndicator")
    }

    private var dots: some View {
        HStack(spacing: 4) {
            ForEach(pages, id: \.self) { page in
                Capsule()
                    .fill(.white.opacity(page == current ? 0.95 : 0.35))
                    .frame(width: page == current ? 12 : 5, height: 5)
            }
        }
    }

    private var title: String {
        switch current {
        case .media: return locale.nf("notchflow.mirror.tab.music", fallback: "Music")
        case .tray: return locale.nf("notchflow.mirror.tab.tray", fallback: "Files")
        case .mirror: return locale.nf("notchflow.mirror.title", fallback: "Mirror")
        case nil: return ""
        }
    }
}
