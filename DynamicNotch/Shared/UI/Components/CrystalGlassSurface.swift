import SwiftUI

/// Shared optical treatment for application chrome. Content retains its own colors.
enum CrystalGlassPalette {
    static let defaultTransparency = 0.78
    static let edgeHighlight = LinearGradient(stops: [
        .init(color: .white.opacity(0.52), location: 0),
        .init(color: .white.opacity(0.10), location: 0.35),
        .init(color: .white.opacity(0.06), location: 0.65),
        .init(color: .white.opacity(0.30), location: 1)
    ], startPoint: .topLeading, endPoint: .bottomTrailing)
}

struct CrystalGlassSurface: View {
    var cornerRadius: CGFloat = 16
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let amount = CrystalGlassPalette.defaultTransparency
        Group {
            if reduceTransparency {
                shape.fill(Color(nsColor: .windowBackgroundColor))
            } else {
                shape.fill((colorScheme == .dark ? Color.black : .white).opacity((1 - amount) * 0.28 + 0.025))
                    .glassEffect(.clear, in: shape)
                    .overlay { shape.strokeBorder(CrystalGlassPalette.edgeHighlight, lineWidth: 0.65) }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct CrystalGlassControlSurface: ViewModifier {
    var cornerRadius: CGFloat
    var selected: Bool
    var isVisible: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if reduceTransparency {
            content.background(Color(nsColor: .controlBackgroundColor).opacity(isVisible ? 1 : 0), in: shape)
                .overlay { shape.strokeBorder(.primary.opacity(isVisible ? (selected ? 0.5 : 0.2) : 0), lineWidth: selected ? 1.5 : 0.5).allowsHitTesting(false) }
        } else {
            content
                .background(.white.opacity(isVisible ? (selected ? 0.18 : 0.025) : 0), in: shape)
                .glassEffect(isVisible ? .clear.interactive() : .identity, in: shape)
        }
    }
}

extension View {
    func crystalGlassControl(cornerRadius: CGFloat = 12, selected: Bool = false, isVisible: Bool = true) -> some View {
        modifier(CrystalGlassControlSurface(cornerRadius: cornerRadius, selected: selected, isVisible: isVisible))
    }
}

struct CrystalGlassButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 12
    var selected = false
    var hitSize: CGSize? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .crystalGlassControl(cornerRadius: cornerRadius, selected: selected)
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.96 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.8), value: configuration.isPressed)
            .frame(minWidth: hitSize?.width, minHeight: hitSize?.height)
            .contentShape(Rectangle())
    }
}
