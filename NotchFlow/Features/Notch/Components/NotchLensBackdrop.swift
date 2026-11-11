import SwiftUI
internal import AppKit

/// Canopy-style notch glass: a progressive blur of the desktop behind the notch whose edges
/// bend the image like a lens. Built from Core Animation's backdrop layer and its
/// `variableBlur` and `displacementMap` filters (private, like the SkyLight calls this app
/// already makes). `isAvailable` is false when the classes are missing; callers then fall
/// back to SwiftUI glass.
struct NotchLensParameters: Equatable {
    /// Blur starts at this fraction of the height (top = 0) and reaches `blurRadius` at `blurEnd`.
    var blurStart: CGFloat = 0.49
    var blurEnd: CGFloat = 0.76
    var blurRadius: CGFloat = 3
    /// Lens band as a fraction of the shorter side, and how far (pt) the edge pixels are pulled.
    var lensBand: CGFloat = 0.16
    var lensAmount: CGFloat = 0
}

enum NotchLensBackdrop {
    static var isAvailable: Bool {
        NSClassFromString("CABackdropLayer") is CALayer.Type && filter("variableBlur") != nil
    }

    static func filter(_ type: String) -> NSObject? {
        guard let cls = NSClassFromString("CAFilter") as? NSObject.Type else { return nil }
        let selector = NSSelectorFromString("filterWithType:")
        guard cls.responds(to: selector) else { return nil }
        return cls.perform(selector, with: type)?.takeUnretainedValue() as? NSObject
    }

    /// Alpha ramp for `variableBlur`: 0 above `start`, 1 from `end` to the bottom.
    static func blurMask(start: CGFloat, end: CGFloat) -> CGImage? {
        let h = 256
        guard let ctx = CGContext(data: nil, width: 4, height: h, bitsPerComponent: 8, bytesPerRow: 16,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                        colors: [CGColor(gray: 0, alpha: 1), CGColor(gray: 0, alpha: 0)] as CFArray,
                                        locations: [0, 1]) else { return nil }
        // Core Graphics origin is bottom-left.
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: CGFloat(h) * (1 - end)),
                               end: CGPoint(x: 0, y: CGFloat(h) * (1 - start)),
                               options: [.drawsBeforeStartLocation])
        return ctx.makeImage()
    }

    enum Edge { case bottomAndLeft, right }

    /// Displacement magnitudes for `displacementMap`. The filter treats 0 as "no offset" and
    /// takes the direction from the sign of `inputAmount`, so opposite edges need two maps.
    static func lensMap(edge: Edge, band: CGFloat, aspect: CGFloat) -> CGImage? {
        let w = 128, h = max(16, Int(128 / max(aspect, 0.25)))
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let bandX = Double(band) / Double(max(aspect, 0.25)), bandY = Double(band)
        func falloff(_ d: Double) -> Double { d >= 1 ? 0 : (1 - d) * (1 - d) }
        for y in 0..<h {
            let v = Double(y) / Double(h - 1)          // 0 top … 1 bottom
            for x in 0..<w {
                let u = Double(x) / Double(w - 1)
                var dx = 0.0, dy = 0.0
                switch edge {
                case .bottomAndLeft:
                    dx = falloff(u / bandX)
                    dy = falloff((1 - v) / bandY)
                case .right:
                    dx = falloff((1 - u) / bandX)
                }
                let i = (y * w + x) * 4
                pixels[i] = UInt8(min(255, dx * 255))
                pixels[i + 1] = UInt8(min(255, dy * 255))
                pixels[i + 3] = 255
            }
        }
        return pixels.withUnsafeMutableBytes { bytes -> CGImage? in
            CGContext(data: bytes.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                      space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
        }
    }
}

final class NotchLensBackdropView: NSView {
    private var backdrop: CALayer?
    private var applied: (NotchLensParameters, CGSize)?
    var parameters = NotchLensParameters() { didSet { needsLayout = true } }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        guard let cls = NSClassFromString("CABackdropLayer") as? CALayer.Type else { return }
        let layer = cls.init()
        layer.setValue(true, forKey: "windowServerAware")
        layer.setValue(1.0, forKey: "scale")
        self.layer?.addSublayer(layer)
        backdrop = layer
    }

    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        guard let backdrop else { return }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        backdrop.frame = bounds
        CATransaction.commit()
        let size = bounds.size
        guard size.width > 1, size.height > 1 else { return }
        if let applied, applied.0 == parameters, abs(applied.1.height - size.height) < 8,
           abs(applied.1.width - size.width) < 8 { return }
        applied = (parameters, size)
        var filters: [NSObject] = []
        if parameters.blurRadius > 0, let blur = NotchLensBackdrop.filter("variableBlur") {
            blur.setValue(parameters.blurRadius, forKey: "inputRadius")
            blur.setValue(true, forKey: "inputNormalizeEdges")
            blur.setValue(NotchLensBackdrop.blurMask(start: parameters.blurStart, end: parameters.blurEnd),
                          forKey: "inputMaskImage")
            filters.append(blur)
        }
        let aspect = size.width / size.height
        for (edge, sign) in [(NotchLensBackdrop.Edge.bottomAndLeft, 1.0), (.right, -1.0)] {
            guard parameters.lensAmount > 0, let lens = NotchLensBackdrop.filter("displacementMap") else { continue }
            lens.setValue(NotchLensBackdrop.lensMap(edge: edge, band: parameters.lensBand, aspect: aspect),
                          forKey: "inputMaskImage")
            lens.setValue(Double(parameters.lensAmount) * sign, forKey: "inputAmount")
            filters.append(lens)
        }
        backdrop.filters = filters
    }
}

struct NotchLensBackdropRepresentable: NSViewRepresentable {
    var parameters = NotchLensParameters()
    func makeNSView(context: Context) -> NotchLensBackdropView {
        let view = NotchLensBackdropView(frame: .zero)
        view.parameters = parameters
        return view
    }
    func updateNSView(_ view: NotchLensBackdropView, context: Context) {
        if view.parameters != parameters { view.parameters = parameters }
    }
}

/// Apple's glass in the hidden lensing variant Canopy uses (`_variant` 11): fully clear,
/// strong edge refraction, unaffected by the system Liquid Glass tint slider.
enum NotchLensGlass {
    static let lensingVariant = 11
    static var isAvailable: Bool {
        NSGlassEffectView().responds(to: NSSelectorFromString("set_variant:"))
    }
}

struct NotchLensGlassRepresentable: NSViewRepresentable {
    var cornerRadius: CGFloat
    func makeNSView(context: Context) -> NSGlassEffectView {
        let view = NSGlassEffectView()
        view.style = .clear
        view.cornerRadius = cornerRadius
        if NotchLensGlass.isAvailable { view.setValue(NotchLensGlass.lensingVariant, forKey: "_variant") }
        return view
    }
    func updateNSView(_ view: NSGlassEffectView, context: Context) {
        if view.cornerRadius != cornerRadius { context.animate { view.cornerRadius = cornerRadius } }
    }
}
