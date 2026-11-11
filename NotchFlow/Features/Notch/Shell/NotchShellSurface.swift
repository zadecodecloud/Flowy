import SwiftUI

// Notch shell surface, taken from notchflow-clean (`Shell/NotchOutline.swift`,
// `Surface/ShellSurface.swift`, `Surface/GlassDimming.swift`) and adapted to this app's
// settings types.

/// Vertical dimming of the expanded glass, tuned after Apple's new "Search or Ask" (Siri)
/// panel on iPhone: solid black only across the camera band, a short fade, then fully clear
/// glass with no white wash, no blur and no residual dim, so what is behind stays sharp.
/// Transmission is the share of the desktop that shows through at height fraction `y`
/// (top = 0, bottom = 1).
struct ShellGlassDimming: Equatable {
    /// Solid black from the top down to this fraction of the height.
    static let solidBlack: CGFloat = 0.44
    /// The glass is fully clear from this fraction of the height down.
    static let clearLine: CGFloat = 0.86
    /// The fade never starts closer than this (as a fraction) below the camera band.
    static let bandMargin: CGFloat = 0.03
    static let residualDim: CGFloat = 0

    static let whiteTint: Double = 0
    static let rimWidth: CGFloat = 0.6
    static let rimOpacity: Double = 0.5
    /// A soft inner glow along the clear edges, like the luminous rim of Apple's glass.
    static let glowOpacity: Double = 0.16
    static let glowWidth: CGFloat = 7
    /// How far below `clearStart` the fallback's opaque cap fades out.
    static let fallbackCapFade: CGFloat = 0.12
    /// No backdrop blur: the clear area stays sharp. Edge refraction comes from a small
    /// displacement plus Apple's lensing glass.
    static let lensBlurRadius: CGFloat = 0
    static let lensAmount: CGFloat = 8
    static let lensBand: CGFloat = 0.12

    var clearStart: CGFloat
    var clearEnd: CGFloat

    /// The profile for a surface of `size` whose top `bandHeight` points cover the camera.
    init(size: CGSize, bandHeight: CGFloat) {
        // Chosen by the owner in the preview (2026-11-10): solid black down to 44 % of the
        // height, then easing to fully clear at 86 %. A very short surface still keeps the
        // whole camera band black.
        let band = size.height > 1 ? bandHeight / size.height : 0
        let start = min(0.8, max(Self.solidBlack, band + Self.bandMargin))
        clearStart = start
        clearEnd = min(0.98, max(Self.clearLine, start + 0.1))
    }

    static func smoothstep(_ edge0: CGFloat, _ edge1: CGFloat, _ x: CGFloat) -> CGFloat {
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }

    func transmission(at y: CGFloat, transparency: CGFloat) -> CGFloat {
        let clear = min(max(transparency, 0), 1) * (1 - Self.residualDim)
        return clear * Self.smoothstep(clearStart, clearEnd, y)
    }

    /// Black overlay whose opacity is 1 − transmission.
    func dimmingGradient(transparency: CGFloat, steps: Int = 24) -> LinearGradient {
        let stops = (0...steps).map { index -> Gradient.Stop in
            let y = CGFloat(index) / CGFloat(steps)
            return .init(color: .black.opacity(Double(1 - transmission(at: y, transparency: transparency))),
                         location: y)
        }
        return LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
    }

    /// Hides outlines across the camera band and fades them in towards the clear area.
    var outlineMask: LinearGradient {
        LinearGradient(stops: [
            .init(color: .clear, location: 0),
            .init(color: .clear, location: clearStart),
            .init(color: .white, location: clearEnd),
            .init(color: .white, location: 1),
        ], startPoint: .top, endPoint: .bottom)
    }

    /// The fallback's opaque black cap: solid to just past `clearStart`, then fading out.
    var fallbackCap: LinearGradient {
        LinearGradient(stops: [
            .init(color: .black, location: 0),
            .init(color: .black, location: clearStart + 0.02),
            .init(color: .clear, location: min(1, clearStart + 0.02 + Self.fallbackCapFade)),
        ], startPoint: .top, endPoint: .bottom)
    }

    var lensParameters: NotchLensParameters {
        NotchLensParameters(blurStart: clearStart, blurEnd: clearEnd, blurRadius: Self.lensBlurRadius,
                            lensBand: Self.lensBand, lensAmount: Self.lensAmount)
    }
}

/// The notch outline. On notch screens the top corners flare outward into the menu bar with
/// `topRadius` and the bottom corners round with `bottomRadius`. In island mode it is a
/// rounded rectangle with `bottomRadius` on all four corners.
struct NotchOutline: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat
    var isIsland = false

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set { topRadius = newValue.first; bottomRadius = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        if isIsland {
            let radius = min(bottomRadius, rect.height / 2, rect.width / 2)
            return Path(roundedRect: rect, cornerRadius: max(0, radius), style: .continuous)
        }
        let top = max(0, min(topRadius, rect.width / 4, rect.height / 2))
        let bottom = max(0, min(bottomRadius, (rect.width - 2 * top) / 2, rect.height - top))
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.minX + top, y: rect.minY + top),
                          control: CGPoint(x: rect.minX + top, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + top, y: rect.maxY - bottom))
        path.addQuadCurve(to: CGPoint(x: rect.minX + top + bottom, y: rect.maxY),
                          control: CGPoint(x: rect.minX + top, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - top - bottom, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - top, y: rect.maxY - bottom),
                          control: CGPoint(x: rect.maxX - top, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY + top))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                          control: CGPoint(x: rect.maxX - top, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

/// Draws the notch surface. Compact and idle shapes are pure black with no outline. When
/// expanded, the Glass style shows the progressive blur, the lensing glass, a faint white
/// tint, the vertical dimming, a rim and the content outline; the Black style shows solid
/// black and the outline. The glass layers stay in the hierarchy while the shape resizes
/// (re-creating them mid-animation flickers); a black cover cross-fades over them.
struct ShellSurface: View {
    var shape: NotchOutline
    var isExpanded: Bool
    var style: NotchBackgroundStyle
    var transparency: Double
    /// The content outline, already combined with the user's opacity; nil when off.
    var outline: Color?
    var outlineWidth: CGFloat = 1
    /// Height of the camera band at the top, which always stays black. 0 uses the defaults.
    var bandHeight: CGFloat = 0

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    static var lensAvailable: Bool { NotchLensBackdrop.isAvailable && NotchLensGlass.isAvailable }

    /// How far the lensing glass extends above the screen so its top edge shows no lens.
    static let glassTopExtension: CGFloat = 60

    private var usesGlass: Bool { style.effectiveStyle(reduceTransparency: reduceTransparency) == .glass }

    var body: some View {
        GeometryReader { proxy in
            let dimming = ShellGlassDimming(size: proxy.size, bandHeight: bandHeight)
            ZStack {
                if usesGlass {
                    glass(size: proxy.size, dimming: dimming)
                }
                Color.black
                    .opacity(usesGlass && isExpanded ? 0 : 1)
                if usesGlass {
                    Group {
                        // Soft inner glow, then the thin bright rim.
                        shape
                            .stroke(Color.white.opacity(ShellGlassDimming.glowOpacity),
                                    lineWidth: ShellGlassDimming.glowWidth)
                            .blur(radius: ShellGlassDimming.glowWidth / 2)
                        shape
                            .stroke(Color.white.opacity(ShellGlassDimming.rimOpacity),
                                    lineWidth: ShellGlassDimming.rimWidth * 2)
                    }
                    .mask(dimming.outlineMask)
                    .opacity(isExpanded ? 1 : 0)
                }
                if let outline {
                    shape
                        .stroke(outline, lineWidth: outlineWidth * 2)
                        .mask(dimming.outlineMask)
                        .opacity(isExpanded ? 1 : 0)
                }
            }
            .clipShape(shape)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func glass(size: CGSize, dimming: ShellGlassDimming) -> some View {
        let inset = shape.isIsland ? 0 : shape.topRadius
        let extensionHeight = shape.isIsland ? 0 : Self.glassTopExtension
        ZStack {
            if Self.lensAvailable {
                NotchLensBackdropRepresentable(parameters: dimming.lensParameters)
                NotchLensGlassRepresentable(cornerRadius: shape.bottomRadius)
                    .frame(width: max(1, size.width - 2 * inset), height: size.height + extensionHeight)
                    .offset(y: -extensionHeight / 2)
            } else {
                Color.clear
                    .glassEffect(.clear, in: shape)
            }
            if ShellGlassDimming.whiteTint > 0 {
                Color.white.opacity(ShellGlassDimming.whiteTint)
            }
            dimming.dimmingGradient(transparency: transparency)
            if !Self.lensAvailable {
                dimming.fallbackCap
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

/// The soft outer shadow. It is a sibling of the surface with the interior cut away, so a
/// transparent surface is never greyed out by a shadow behind it.
struct ShellHalo: View {
    var shape: NotchOutline
    var size: CGSize
    var isVisible: Bool

    // Deeper than notchflow-clean's 20 pt / 20 % so the open notch lifts off the screen.
    static let radius: CGFloat = 24
    static let opacity: Double = 0.45
    static let offsetY: CGFloat = 6
    private static let margin: CGFloat = 60

    var body: some View {
        shape
            .fill(Color.black)
            .frame(width: size.width, height: size.height)
            .shadow(color: .black.opacity(Self.opacity), radius: Self.radius, y: Self.offsetY)
            .padding(Self.margin)
            .mask {
                ZStack {
                    Rectangle()
                    shape
                        .frame(width: size.width, height: size.height)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
            }
            .padding(-Self.margin)
            .opacity(isVisible ? 1 : 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
