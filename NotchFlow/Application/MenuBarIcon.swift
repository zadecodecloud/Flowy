internal import AppKit

/// Menu bar glyph: the NotchFlow capsule, drawn as a vector so it stays sharp at any size.
enum MenuBarIcon {
    /// ← Chỉnh kích thước icon trên thanh menu tại đây (pt).
    static let size: CGFloat = 23

    /// Capsule length / thickness and tilt — same proportions as the app icon.
    private static let aspect: CGFloat = 1.42
    private static let tiltDegrees: CGFloat = 28

    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            // Fit the rotated capsule inside the square with a little breathing room.
            let angle = tiltDegrees * .pi / 180
            let inset = rect.width * 0.06
            let box = rect.width - inset * 2
            let thickness = box / (aspect * sin(angle) + cos(angle))
            let length = thickness * aspect
            let capsule = NSRect(x: -length / 2, y: -thickness / 2, width: length, height: thickness)

            let transform = NSAffineTransform()
            transform.translateX(by: rect.midX, yBy: rect.midY)
            transform.rotate(byRadians: angle)
            transform.concat()

            NSColor.black.setFill()
            NSBezierPath(roundedRect: capsule, xRadius: thickness / 2, yRadius: thickness / 2).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "NotchFlow"
        return image
    }()
}
