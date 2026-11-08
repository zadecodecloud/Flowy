import SwiftUI

/// Amount of desktop visible through the tint, from the top to the bottom of the notch.
struct NotchGlassProfile {
    let transparency: Double

    func transmission(at fraction: Double) -> Double {
        let lower = min(1, max(0, (fraction - 0.5) / 0.42))
        let smooth = lower * lower * (3 - 2 * lower)
        return ApplicationSettingsStore.clampGlassTransparency(transparency) * smooth
    }

    var shade: LinearGradient {
        let stops = [0.0, 0.5, 0.57, 0.64, 0.71, 0.78, 0.85, 0.92, 1.0].map { y in
            Gradient.Stop(color: .black.opacity(1 - transmission(at: y)), location: y)
        }
        return LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
    }

    var rim: LinearGradient {
        LinearGradient(stops: [
            .init(color: .clear, location: 0.5),
            .init(color: .white.opacity(transmission(at: 0.71)), location: 0.71),
            .init(color: .white.opacity(transmission(at: 1)), location: 1)
        ], startPoint: .top, endPoint: .bottom)
    }
}

struct NotchBackgroundSurface: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let isExpanded: Bool
    let style: NotchBackgroundStyle
    var glassTransparency: Double = CrystalGlassPalette.defaultTransparency
    let topCornerRadius: CGFloat
    let bottomCornerRadius: CGFloat
    let isDynamicIsland: Bool
    let dynamicIslandCornerRadius: CGFloat
    let strokeColor: Color
    var strokeWidth: CGFloat = 2

    var body: some View {
        if isDynamicIsland {
            presentation(in: DynamicIslandShape(cornerRadius: dynamicIslandCornerRadius))
        } else {
            presentation(in: NotchShape(topCornerRadius: topCornerRadius, bottomCornerRadius: bottomCornerRadius))
        }
    }

    private func presentation<S: Shape>(in shape: S) -> some View {
        // Keep the same native lens alive while the shell resizes. Replacing it
        // on hover inserts an already-expanded AppKit view into a moving mask.
        surface(in: shape)
            .overlay {
                // This opaque cover also removes the rim/stroke in compact mode.
                shape.fill(.black).opacity(isExpanded ? 0 : 1)
            }
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private func surface<S: Shape>(in shape: S) -> some View {
        switch style.effectiveStyle(reduceTransparency: reduceTransparency) {
        case .black:
            shape.fill(.black).overlay { shape.stroke(strokeColor, lineWidth: strokeWidth) }
        case .glass:
            let profile = NotchGlassProfile(transparency: glassTransparency)
            ZStack {
                // The same native SwiftUI lens is used in the live notch and Settings.
                // Do not rasterize/clip an AppKit glass subview into an offscreen group.
                RoundedRectangle(cornerRadius: isDynamicIsland ? dynamicIslandCornerRadius : bottomCornerRadius, style: .continuous)
                    .fill(.clear)
                    .glassEffect(.clear, in: .rect(cornerRadius: isDynamicIsland ? dynamicIslandCornerRadius : bottomCornerRadius))
                    .clipShape(shape)
                shape.fill(profile.shade)
                ZStack {
                    shape.stroke(CrystalGlassPalette.edgeHighlight, lineWidth: 0.75)
                    shape.stroke(strokeColor, lineWidth: strokeWidth)
                }
                .mask(profile.rim)
            }
            .allowsHitTesting(false)
        }
    }
}
