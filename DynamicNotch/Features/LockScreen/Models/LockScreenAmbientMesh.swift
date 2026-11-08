import SwiftUI
internal import AppKit

/// Album-derived colors and soft fields that drift without moving the artwork.
enum LockScreenAmbientMesh {
    struct Field: Equatable {
        let center: CGPoint
        let radius: CGFloat
    }

    static func fields(at time: TimeInterval) -> [Field] {
        (0..<7).map { index in
            let phase = Double(index) * 1.7
            return Field(center: CGPoint(x: 0.5 + sin(time * 0.26 + phase) * 0.46,
                                         y: 0.5 + cos(time * 0.31 + phase * 1.3) * 0.44),
                         radius: 0.52 + sin(time * 0.19 + phase) * 0.12)
        }
    }

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

    @MainActor
    static func colors(from image: NSImage?) -> [Color] {
        guard let image, let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return fallbackColors
        }
        var pixels = [UInt8](repeating: 0, count: 36)
        let rendered = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: 3, height: 3,
                bitsPerComponent: 8, bytesPerRow: 12, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
            context.interpolationQuality = .high
            context.draw(cg, in: CGRect(x: 0, y: 0, width: 3, height: 3))
            return true
        }
        guard rendered else { return fallbackColors }
        return stride(from: 0, to: 36, by: 4).map { index in
            let color = NSColor(srgbRed: CGFloat(pixels[index]) / 255,
                                green: CGFloat(pixels[index + 1]) / 255,
                                blue: CGFloat(pixels[index + 2]) / 255, alpha: 1)
            var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
            color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
            return Color(nsColor: NSColor(hue: hue, saturation: min(0.95, saturation * 1.08),
                                          brightness: min(0.95, 0.16 + brightness * 0.82), alpha: 1))
        }
    }
}
