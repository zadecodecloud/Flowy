import SwiftUI

struct LockScreenWidgetSurface: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let style: LockScreenWidgetAppearanceStyle
    let tintStyle: LockScreenWidgetTintStyle
    let cornerRadius: CGFloat
    var liquidGlassVariant: Int = 8

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        baseSurface(shape: shape)
            .overlay {
                if let tintColor = tintStyle.resolvedColor() {
                    shape
                        .fill(tintColor.opacity(tintOpacity))
                }
            }
            .overlay {
                if style != .liquidGlass {
                    shape.stroke(strokeColor, lineWidth: 1)
                }
            }
    }

    @ViewBuilder
    private func baseSurface(shape: RoundedRectangle) -> some View {
        switch style {
        case .ultraThinMaterial:
            shape.fill(.ultraThinMaterial)

        case .ultraThickMaterial:
            shape.fill(.ultraThickMaterial)

        case .liquidGlass:
            Group {
                if reduceTransparency {
                    shape.fill(Color(nsColor: .windowBackgroundColor))
                } else {
                    clearGlass(shape: shape)
                }
            }
                .environment(\.controlActiveState, .active)
        }
    }

    /// The notch's clear glass (sharp backdrop, edge refraction, bright rim and soft inner
    /// glow), without the notch's black fade: one even black layer keeps text legible.
    static let clearGlassDim: Double = 0.20

    @ViewBuilder
    private func clearGlass(shape: RoundedRectangle) -> some View {
        ZStack {
            if ShellSurface.lensAvailable {
                NotchLensBackdropRepresentable(parameters: NotchLensParameters(
                    blurStart: 0, blurEnd: 1, blurRadius: 0,
                    lensBand: ShellGlassDimming.lensBand, lensAmount: ShellGlassDimming.lensAmount))
                NotchLensGlassRepresentable(cornerRadius: cornerRadius)
            } else {
                Color.clear.glassEffect(.clear, in: shape)
            }
            Color.black.opacity(Self.clearGlassDim)
            shape
                .stroke(Color.white.opacity(ShellGlassDimming.glowOpacity), lineWidth: ShellGlassDimming.glowWidth)
                .blur(radius: ShellGlassDimming.glowWidth / 2)
            shape
                .strokeBorder(Color.white.opacity(ShellGlassDimming.rimOpacity), lineWidth: ShellGlassDimming.rimWidth)
        }
        .clipShape(shape)
    }

    private var tintOpacity: Double {
        switch style {
        case .ultraThinMaterial:
            return 0.14
        case .ultraThickMaterial:
            return 0.18
        case .liquidGlass:
            return 0.025
        }
    }

    private var strokeColor: Color {
        if let tintColor = tintStyle.resolvedColor() {
            switch style {
            case .ultraThinMaterial:
                return tintColor.opacity(0.24)
            case .ultraThickMaterial:
                return tintColor.opacity(0.28)
            case .liquidGlass:
                return tintColor.opacity(0.18)
            }
        }

        switch style {
        case .ultraThinMaterial:
            return .white.opacity(0.15)
        case .ultraThickMaterial:
            return .white.opacity(0.18)
        case .liquidGlass:
            return .white.opacity(0.12)
        }
    }
}
