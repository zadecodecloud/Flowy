import SwiftUI
internal import AppKit

/// A passive material that samples the desktop behind the overlay panel.
/// It is separate from the content, so it never intercepts pointer events.
@available(macOS 26.0, *)
final class NotchGlassBackdropView: NSView {
    let backdrop = NSVisualEffectView()
    let glass = NSGlassEffectView()
    private var appliedWindowBackground = false

    func configure(windowBackground: Bool, colorScheme: ColorScheme) {
        let name: NSAppearance.Name = colorScheme == .dark ? .darkAqua : .aqua
        if appearance?.name != name { appearance = NSAppearance(named: name) }
        // Playback updates must not repeatedly reset AppKit's adaptive material.
        guard appliedWindowBackground != windowBackground else { return }
        appliedWindowBackground = windowBackground
        glass.isHidden = windowBackground
        backdrop.isHidden = !windowBackground
        backdrop.material = windowBackground ? .underWindowBackground : .hudWindow
        backdrop.alphaValue = windowBackground ? 0.72 : 0
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        appearance = NSAppearance(named: .darkAqua)
        backdrop.material = .hudWindow
        backdrop.blendingMode = .behindWindow
        backdrop.state = .active
        // The notch uses one optical material. A second adaptive HUD material
        // underneath clear glass can add a milky wash as the backdrop changes.
        backdrop.alphaValue = 0
        backdrop.isHidden = true
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backdrop)

        glass.style = .clear
        if #available(macOS 27.0, *) { glass.effectIsInteractive = false }
        glass.tintColor = nil
        glass.translatesAutoresizingMaskIntoConstraints = false
        addSubview(glass)

        NSLayoutConstraint.activate([
            backdrop.leadingAnchor.constraint(equalTo: leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: trailingAnchor),
            backdrop.topAnchor.constraint(equalTo: topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: bottomAnchor),
            glass.leadingAnchor.constraint(equalTo: leadingAnchor),
            glass.trailingAnchor.constraint(equalTo: trailingAnchor),
            glass.topAnchor.constraint(equalTo: topAnchor),
            glass.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

@available(macOS 26.0, *)
struct NotchGlassBackdrop: NSViewRepresentable {
    var cornerRadius: CGFloat
    var colorScheme: ColorScheme = .dark
    var isWindowBackground = false

    func makeNSView(context: Context) -> NotchGlassBackdropView {
        let view = NotchGlassBackdropView(frame: .zero)
        view.glass.cornerRadius = max(0, cornerRadius)
        configureMaterial(view)
        return view
    }

    func updateNSView(_ view: NotchGlassBackdropView, context: Context) {
        // Use SwiftUI's transaction for the native lens and its animated mask.
        if view.glass.cornerRadius != max(0, cornerRadius) {
            context.animate { view.glass.cornerRadius = max(0, cornerRadius) }
        }
        configureMaterial(view)
    }

    private func configureMaterial(_ view: NotchGlassBackdropView) {
        // A whole document window needs a single diffusion plane beneath its
        // optical cards. Stacking two full-window lenses washes out foreground text.
        view.configure(windowBackground: isWindowBackground, colorScheme: colorScheme)
    }
}
