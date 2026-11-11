import SwiftUI

struct NotchSurfaceContainerView: View {
    @ObservedObject var notchViewModel: NotchViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel
    
    var body: some View {
        shell
            // Hover and press feedback from notchflow-clean: the whole shell (surface and
            // content) grows slightly from the top while hovered or pressed.
            .scaleEffect(notchViewModel.shellHoverScale,
                         anchor: notchViewModel.isDynamicIsland ? .center : .top)
            .animation(NotchViewModel.hoverAnimation, value: notchViewModel.shellHoverScale)
    }

    private var shell: some View {
        notchSurface
            // The drop shadow is a sibling behind the shell. A `.shadow` on an ancestor would
            // render the glass into an offscreen layer and collapse its refraction.
            .background { outerShadow }
            .overlay {
                contentOverlayWrapped
            }
            .overlay(alignment: .top) {
                if notchViewModel.isDynamicIsland,
                   settingsViewModel.application.notchBackgroundStyle == .black,
                   notchViewModel.notchModel.baseWidth > 0,
                   notchViewModel.notchModel.baseHeight > 0 {
                    DynamicIslandShape(cornerRadius: notchViewModel.notchModel.baseHeight * 0.5)
                        .fill(.black)
                        .frame(width: notchViewModel.notchModel.baseWidth, height: notchViewModel.notchModel.baseHeight)
                        .allowsHitTesting(false)
                }
            }
    }
    
    /// The notch outline from notchflow-clean, in notch or island form.
    private var shellShape: NotchOutline {
        if notchViewModel.isDynamicIsland {
            return NotchOutline(topRadius: 0, bottomRadius: notchViewModel.dynamicIslandCornerRadius, isIsland: true)
        }
        return NotchOutline(topRadius: notchViewModel.interactiveCornerRadius.top,
                            bottomRadius: notchViewModel.interactiveCornerRadius.bottom)
    }

    /// Surface from notchflow-clean (`ShellSurface`): black when compact, glass or black with
    /// the content outline when expanded.
    @ViewBuilder
    private var notchSurface: some View {
        ShellSurface(
            shape: shellShape,
            isExpanded: notchViewModel.isDisplayingExpandedLiveActivity,
            style: settingsViewModel.application.notchBackgroundStyle,
            transparency: settingsViewModel.application.notchGlassTransparency,
            outline: shouldShowStroke ? visibleStrokeColor : nil,
            outlineWidth: 1,
            bandHeight: notchViewModel.notchModel.baseHeight
        )
    }

    /// Outer shadow from notchflow-clean (`ShellHalo`), shown while expanded.
    private var outerShadow: some View {
        GeometryReader { proxy in
            ShellHalo(shape: shellShape, size: proxy.size,
                      isVisible: notchViewModel.isDisplayingExpandedLiveActivity)
        }
    }

    /// Content is clipped exactly to the notch outline, as in notchflow-clean.
    private var contentOverlayWrapped: some View {
        contentOverlay
            .environment(\.isNotchlessScreen, notchViewModel.isDynamicIsland)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(shellShape)
    }

    @ViewBuilder
    private var contentOverlay: some View {
        if let content = notchViewModel.displayedContent {
            renderedContentView(for: content)
                .resizeAwareBlur(
                    size: notchViewModel.interactiveNotchSize,
                    baseSize: notchViewModel.displayedBaseNotchSize,
                    baseHeight: notchViewModel.notchModel.baseHeight,
                    anchor: notchViewModel.isDynamicIsland ? .center : .center,
                    // notchflow-clean does not blur content while the shape resizes; only
                    // the swipe feedback (blur and fade) remains.
                    isResizeEffectEnabled: false,
                    interactiveBlur: notchViewModel.contentResizeBlurRadius,
                    interactiveOpacity: notchViewModel.contentResizeOpacity,
                    swipeProgress: notchViewModel.easedSwipeStretchProgress,
                    swipeInteraction: notchViewModel.swipeInteraction
                )
                .id(notchViewModel.displayedPresentationID)
                .transition(
                    notchViewModel.contentTransition(
                        notchWidth: notchViewModel.presentedNotchSize.width,
                        notchHeight: notchViewModel.presentedNotchSize.height,
                        baseWidth: notchViewModel.notchModel.baseWidth,
                        baseHeight: notchViewModel.notchModel.baseHeight,
                        isExpandedPresentation: notchViewModel.isDisplayingExpandedLiveActivity
                    )
                )
        }
    }
    
    @MainActor
    @ViewBuilder
    private func renderedContentView(for content: NotchContentProtocol) -> some View {
        Group {
            if notchViewModel.isDisplayingExpandedLiveActivity {
                content.expandedView()
            } else {
                content.compactView()
            }
        }
        .id(content.id)
    }
    
    private var visibleStrokeColor: Color {
        let strokeOpacity = settingsViewModel.application.notchStrokeOpacity
        let baseColor = notchViewModel.displayedContent?.strokeColor ?? notchViewModel.cachedStrokeColor
        return baseColor.opacity(strokeOpacity)
    }
    
    private var shouldShowStroke: Bool {
        let isStrokeEnabled = settingsViewModel.application.isShowNotchStrokeEnabled || notchViewModel.displayedContent?.id == NotchContentRegistry.NotchSize.strokeOpacity.id
        return isStrokeEnabled && notchViewModel.shouldRenderStroke
    }
}

/// Soft shadow outside the notch outline only; the interior is cut away so nothing dark
/// sits behind the clear glass.
struct NotchOuterShadow<S: Shape>: View {
    let shape: S
    let isVisible: Bool

    var body: some View {
        shape.fill(.black)
            .shadow(color: .black.opacity(isVisible ? 0.2 : 0), radius: 20)
            .mask {
                Rectangle()
                    .padding(-60)
                    .overlay { shape.fill(.black).blendMode(.destinationOut) }
                    .compositingGroup()
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
