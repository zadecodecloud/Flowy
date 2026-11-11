import SwiftUI
internal import AppKit

/// Album-derived colors and soft fields that drift without moving the artwork.
enum LockScreenAmbientMesh {
    struct Field: Equatable {
        let center: CGPoint
        let radius: CGFloat
    }

    static let fieldCount = 10
    static let radiusRange: ClosedRange<CGFloat> = 0.34...0.64

    /// Ten soft fields on independent orbits. Rates are roughly twice the original drift so
    /// the colors keep visibly flowing, like the full-screen lyrics view in Music.
    /// Overall pace of the ambient motion (1 = original drift rate).
    static let motionPace = 0.65

    static func fields(at elapsed: TimeInterval) -> [Field] {
        let time = elapsed * motionPace
        return (0..<fieldCount).map { index in
            let i = Double(index)
            let phase = i * 1.37
            let rateX = 0.42 + (i.truncatingRemainder(dividingBy: 3)) * 0.09
            let rateY = 0.51 + (i.truncatingRemainder(dividingBy: 4)) * 0.07
            let x = 0.5 + sin(time * rateX + phase) * 0.42 + sin(time * 0.17 + phase * 2.1) * 0.06
            let y = 0.5 + cos(time * rateY + phase * 1.3) * 0.40 + cos(time * 0.23 + phase * 0.7) * 0.06
            let radius = 0.49 + sin(time * 0.33 + phase) * 0.15
            return Field(center: CGPoint(x: min(1, max(0, x)), y: min(1, max(0, y))),
                         radius: min(radiusRange.upperBound, max(radiusRange.lowerBound, radius)))
        }
    }

    /// Palette slot used by each field, cycling through the vivid album colors.
    static let fieldPaletteSlots = [0, 2, 6, 8, 1, 7, 3, 5, 0, 6]

    static func points(at time: TimeInterval, animated: Bool) -> [SIMD2<Float>] {
        let t = animated ? time : 0
        let motion: Float = animated ? 1 : 0
        func wave(_ rate: Double, _ phase: Double = 0) -> Float { Float(sin(t * rate + phase)) * motion }
        return [
            [0, 0], [0.5 + wave(0.17) * 0.24, 0], [1, 0],
            [0, 0.5 + wave(0.14, 1) * 0.26],
            [0.5 + wave(0.13, 2) * 0.25, 0.5 + wave(0.19, 1) * 0.25],
            [1, 0.5 + wave(0.15, 3) * 0.24],
            [0, 1], [0.5 + wave(0.12, 4) * 0.24, 1], [1, 1]
        ]
    }

    static var fallbackColors: [Color] {
        [0.20, 0.28, 0.22, 0.24, 0.32, 0.23, 0.18, 0.26, 0.20].map { Color(white: $0) }
    }

    // MARK: Apple Music-style tone matching

    /// Keeps the artwork's own hue and tone, with the gentle saturation lift Apple Music
    /// applies to its background so colours read as the cover, not as a new palette.
    static func toneMatched(_ c: HSB) -> HSB {
        HSB(h: c.h, s: min(0.95, c.s * 1.15), b: min(0.88, 0.06 + c.b * 0.94))
    }

    /// Spatial colour grid (row-major, top-left first) sampled from the artwork itself.
    @MainActor
    static func grid(from image: NSImage?, side: Int) -> [HSB]? {
        guard let image, let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let rendered = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                          bytesPerRow: side * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
            else { return false }
            context.interpolationQuality = .medium
            context.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard rendered else { return nil }
        var cells: [HSB] = []
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let red = CGFloat(pixels[index]) / 255, green = CGFloat(pixels[index + 1]) / 255, blue = CGFloat(pixels[index + 2]) / 255
            cells.append(HSB(NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)))
        }
        return cells
    }

    /// Nine tone-matched colours from a 3×3 grid of the artwork (slot 4 is the centre). Each
    /// moving field takes the colour of the cover region it maps to, as in Apple Music.
    @MainActor
    static func colors(from image: NSImage?) -> [Color] {
        guard let cells = grid(from: image, side: 3) else { return fallbackColors }
        return cells.map { Color(nsColor: toneMatched($0).color) }
    }

    struct HSB: Equatable {
        var h: CGFloat, s: CGFloat, b: CGFloat
        init(h: CGFloat, s: CGFloat, b: CGFloat) { self.h = h; self.s = s; self.b = b }
        init(_ color: NSColor) {
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            (color.usingColorSpace(.sRGB) ?? color).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            self.init(h: h, s: s, b: b)
        }
        var color: NSColor { NSColor(hue: h, saturation: s, brightness: b, alpha: 1) }
    }
}
