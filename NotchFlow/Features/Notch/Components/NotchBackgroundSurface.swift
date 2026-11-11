import SwiftUI

/// Canopy-tuned notch glass, from the values chosen in the Canopy Notch Lab:
/// black down to `dimEnd`, a smooth opening until `clearStart`, then a light residual dim.
struct NotchGlassProfile {
    /// Extra clarity on top of the lab values (0.05 = +5%). Debug builds can preview other
    /// values with `-NotchFlowDebugClarityBoost`.
    static let clarityBoost = 0.10
    static var effectiveClarityBoost: Double {
        #if DEBUG
        if let override = UserDefaults.standard.object(forKey: "NotchFlowDebugClarityBoost") as? Double { return override }
        if let text = UserDefaults.standard.string(forKey: "NotchFlowDebugClarityBoost"), let value = Double(text) { return value }
        #endif
        return clarityBoost
    }
    static var dimEnd: Double { 0.49 - effectiveClarityBoost * 0.5 }
    static var clearStart: Double { 0.76 - effectiveClarityBoost * 0.5 }
    static var bottomDim: Double { max(0, 0.15 - effectiveClarityBoost) }
    static let tint = 0.02
    static let rimWidth: CGFloat = 0.5
    static let rimBrightness = 0.32
    static let blurRadius: CGFloat = 3
    let transparency: Double

    /// Share of the desktop visible through the dimming at a vertical fraction (top = 0).
    func transmission(at fraction: Double) -> Double {
        let lower = min(1, max(0, (fraction - Self.dimEnd) / (Self.clearStart - Self.dimEnd)))
        let smooth = lower * lower * (3 - 2 * lower)
        return ApplicationSettingsStore.clampGlassTransparency(transparency) * smooth * (1 - Self.bottomDim)
    }

    var shade: LinearGradient {
        let stops = stride(from: 0.0, through: 1.0, by: 0.04).map { y in
            Gradient.Stop(color: .black.opacity(1 - transmission(at: y)), location: y)
        }
        return LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
    }

    /// Opaque cap over the camera band, used above system glass in the fallback path.
    var cap: LinearGradient {
        LinearGradient(stops: [
            .init(color: .black, location: 0),
            .init(color: .black, location: Self.dimEnd - 0.08),
            .init(color: .black.opacity(0), location: Self.dimEnd + 0.04)
        ], startPoint: .top, endPoint: .bottom)
    }

    /// Fades rim and strokes in below the camera band.
    var rim: LinearGradient {
        LinearGradient(stops: [
            .init(color: .clear, location: Self.dimEnd),
            .init(color: .white, location: Self.clearStart),
            .init(color: .white, location: 1)
        ], startPoint: .top, endPoint: .bottom)
    }

    var lens: NotchLensParameters {
        NotchLensParameters(blurStart: Self.dimEnd, blurEnd: Self.clearStart, blurRadius: Self.blurRadius)
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
            shape.fill(.black).overlay { shape.stroke(strokeColor, lineWidth: strokeWidth).opacity(isExpanded ? 1 : 0) }
        case .glass:
            let profile = NotchGlassProfile(transparency: glassTransparency)
            Group {
            if NotchLensBackdrop.isAvailable && NotchLensGlass.isAvailable {
                // Canopy-style (option D): a light progressive blur of the desktop, Apple's
                // lensing glass over it so the edges bend the blurred image, then the dimming,
                // a faint white tint and a thin rim. The glass extends above the frame so only
                // its bottom corners show; the notch shape clips the rest.
                ZStack {
                    NotchLensBackdropRepresentable(parameters: profile.lens)
                        .clipShape(shape)
                    NotchLensGlassRepresentable(cornerRadius: isDynamicIsland ? dynamicIslandCornerRadius : bottomCornerRadius)
                        .padding(.top, isDynamicIsland ? 0 : -48)
                        .clipShape(shape)
                    shape.fill(.white.opacity(NotchGlassProfile.tint))
                    shape.fill(profile.shade)
                    // Strokes straddle the outline; hide them on the compact notch so no rim
                    // shows outside the black cover.
                    Group {
                        shape.stroke(.white.opacity(NotchGlassProfile.rimBrightness), lineWidth: NotchGlassProfile.rimWidth)
                        shape.stroke(strokeColor, lineWidth: strokeWidth)
                    }
                    .mask(profile.rim)
                    .opacity(isExpanded ? 1 : 0)
                }
            } else {
                // Fallback: Apple's clear glass over the dimming, black cap over the camera band.
                ZStack {
                    shape.fill(profile.shade)
                    Color.clear
                        .glassEffect(.clear, in: shape)
                    shape.fill(profile.cap)
                    shape.stroke(strokeColor, lineWidth: strokeWidth)
                        .mask(profile.rim)
                        .opacity(isExpanded ? 1 : 0)
                }
            }
            }
            .allowsHitTesting(false)
        }
    }
}
