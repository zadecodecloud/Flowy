import XCTest
import SwiftUI
import AppKit
import CoreAudio
import ImageIO
import UniformTypeIdentifiers
@testable import DynamicNotch

/// Renders only our fixture view, without capturing the desktop or locking the computer.
@MainActor
final class LockScreenSnapshotTests: XCTestCase {
    func testAmbientBackgroundRendersDifferentFrames() throws {
        let palette: [Color] = [.red, .orange, .blue, .purple, .black, .green, .cyan, .pink, .yellow]
        var frames: [Data] = []
        for time in [0.0, 2.0] {
            let renderer = ImageRenderer(content: LockScreenAmbientField(colors: palette, time: time)
                .frame(width: 320, height: 200))
            let image = try XCTUnwrap(renderer.cgImage)
            let data = try XCTUnwrap(image.dataProvider?.data)
            frames.append(data as Data)
        }
        XCTAssertNotEqual(frames[0], frames[1], "A changing clock must produce actual visible movement")
        var changed = 0
        for (a, b) in zip(frames[0], frames[1]) where abs(Int(a) - Int(b)) > 8 { changed += 1 }
        XCTAssertGreaterThan(changed, frames[0].count / 20)
        if let destination = ProcessInfo.processInfo.environment["NOTCHFLOW_TEST_ARTIFACTS"] {
            try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
            let url = URL(fileURLWithPath: destination).appendingPathComponent("ambient-background.gif")
            let output = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, 60, nil))
            CGImageDestinationSetProperties(output, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
            let albumColors = [Color(red: 0.62, green: 0.53, blue: 0.43), .black,
                               Color(red: 0.3, green: 0.35, blue: 0.4), .black,
                               Color(white: 0.09), .black, Color(white: 0.58), .black,
                               Color(red: 0.37, green: 0.3, blue: 0.23)]
            for index in 0..<60 {
                let renderer = ImageRenderer(content: LockScreenAmbientField(colors: albumColors, time: Double(index) * 0.2)
                    .overlay(Color.black.opacity(0.2)).frame(width: 480, height: 300))
                CGImageDestinationAddImage(output, try XCTUnwrap(renderer.cgImage),
                    [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.2]] as CFDictionary)
            }
            XCTAssertTrue(CGImageDestinationFinalize(output))
        }
    }

    func testPlayerTransitionFrames() async throws {
        guard let destination = ProcessInfo.processInfo.environment["NOTCHFLOW_TEST_ARTIFACTS"],
              let screen = NSScreen.main else { throw XCTSkip("Motion export not requested") }
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { throw XCTSkip("System Reduce Motion enabled") }
        let suite = "NotchFlow.Motion." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(false, forKey: GeneralSettingsStorage.Keys.launchAtLogin)
        let settings = SettingsViewModel(defaults: defaults)
        settings.lockScreen.isLockScreenLyricsEnabled = true
        let service = FakeNowPlayingService()
        let model = NowPlayingViewModel(service: service, lyricsProvider: SnapshotLyricsProvider(), favoritesStore: defaults)
        TestLifetime.retain(model)
        model.startMonitoring()
        let art = NSImage(size: NSSize(width: 300, height: 300))
        art.lockFocus(); NSColor.magenta.setFill(); NSRect(x: 0, y: 0, width: 300, height: 300).fill(); art.unlockFocus()
        let snapshot = makeNowPlayingSnapshot(title: "Motion test", artist: "NotchFlow", duration: 240,
            elapsedTime: 24, playbackRate: 0, artworkData: art.tiffRepresentation)
        service.publish(snapshot)
        let animator = LockScreenPanelAnimator()
        animator.presentImmediately()
        let lock = LockScreenManager(service: InactiveLockScreenMonitoringService(), defaults: defaults)
        let root = ZStack {
            Color.black
            LockScreenNowPlayingPanelView(snapshot: snapshot, artworkImage: art, screen: screen,
                settingsViewModel: settings, nowPlayingViewModel: model, lockScreenManager: lock, animator: animator,
                transitionResponse: 2.0)
        }.frame(width: 960, height: 640)
        let host = NSHostingView(rootView: root)
        let window = NSPanel(contentRect: NSRect(x: 40, y: 40, width: 960, height: 640),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFrontRegardless()
        defer { window.orderOut(nil); window.contentView = nil; window.close(); model.stopMonitoring() }
        try await Task.sleep(for: .milliseconds(250))
        var frames: [CGImage] = []
        var widths: [CGFloat] = []
        func capture() throws {
            host.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let normalized = try normalizedMediaTestBitmap(bitmap)
            frames.append(try XCTUnwrap(normalized.cgImage))
            let scale = CGFloat(normalized.pixelsWide) / 960
            let bytes = try XCTUnwrap(normalized.bitmapData)
            var minX = normalized.pixelsWide, maxX = 0
            // Find the magenta cover, independently of its target layout.
            for y in stride(from: 0, to: normalized.pixelsHigh, by: 8) {
                for x in stride(from: 0, to: normalized.pixelsWide, by: 4) {
                    let offset = y * normalized.bytesPerRow + x * 4
                    if bytes[offset] > 140, bytes[offset + 2] > 140, bytes[offset + 1] < 90 {
                        minX = min(minX, x); maxX = max(maxX, x)
                    }
                }
            }
            widths.append(CGFloat(max(0, maxX - minX)) / scale)
        }
        try capture()
        for step in 0..<4 {
            switch step {
            case 0: animator.expandArtwork()
            case 1: animator.toggleLyrics()
            case 2: animator.toggleLyricsSize()
            default: animator.closeExpandedPlayer()
            }
            for _ in 0..<10 {
                try await Task.sleep(for: .milliseconds(50))
                animator.presentImmediately() // Real manager refreshes must not suppress motion.
                try capture()
            }
        }
        // Render capture is slower than a display frame; inspect at 4x slow motion
        // using the production transition, not a separate mock animation.
        let first = widths.first ?? 0
        let expanded = widths[10]
        XCTAssertGreaterThan(expanded, first * 2)
        XCTAssertTrue(widths[1..<10].contains { $0 > first + 8 && $0 < expanded - 8 },
                      "Cover jumped to its destination instead of animating: \(widths)")
        try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
        let url = URL(fileURLWithPath: destination).appendingPathComponent("player-transitions-slowmotion.gif")
        let output = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames.count, nil))
        CGImageDestinationSetProperties(output, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for frame in frames {
            CGImageDestinationAddImage(output, frame, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.25]] as CFDictionary)
        }
        XCTAssertTrue(CGImageDestinationFinalize(output))
        try widths.map(String.init(describing:)).joined(separator: ", ").write(
            to: URL(fileURLWithPath: destination).appendingPathComponent("transition-cover-widths.txt"), atomically: true, encoding: .utf8)
    }

    func testMediaGlyphRemainsBrightWithVisibleGlass() async throws {
            for visible in [false, true] {
                for selected in [false, true] {
                    let root = ZStack {
                        Color.black
                        GlassEffectContainer(spacing: 0) {
                            Button {} label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(MediaGlassButtonStyle(width: 44, height: 44,
                                selected: selected, alwaysVisible: visible, materialInset: 4))
                        }
                    }
                    .environment(\.colorScheme, .dark)
                    .frame(width: 64, height: 64)
                    let view = NSHostingView(rootView: root)
                    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 64, height: 64),
                        styleMask: .borderless, backing: .buffered, defer: false)
                    window.isReleasedWhenClosed = false
                    window.contentView = view
                    defer { window.contentView = nil; window.close() }
                    try await Task.sleep(for: .milliseconds(120))
                    view.layoutSubtreeIfNeeded()
                    let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    var brightPixels = 0
                    let scale = CGFloat(bitmap.pixelsWide) / 64
                    for x in Int(24 * scale)..<Int(40 * scale) {
                        for y in Int(24 * scale)..<Int(40 * scale) {
                            let c = try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                            if min(c.redComponent, c.greenComponent, c.blueComponent) > 0.85 { brightPixels += 1 }
                        }
                    }
                    XCTAssertGreaterThan(brightPixels, Int(20 * scale * scale),
                        "Glyph obscured: glass=\(visible), selected=\(selected)")
                }
            }
    }

    func testBothExpandedModesCoverEveryScreenEdgeAndCloseRevealsTheLoginBackdrop() async throws {
        let suite = "NotchFlow.Coverage." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(false, forKey: GeneralSettingsStorage.Keys.launchAtLogin)
        let settings = SettingsViewModel(defaults: defaults)
        settings.lockScreen.mediaPanelBackgroundStyle = .black
        let player = NowPlayingViewModel(service: FakeNowPlayingService(), favoritesStore: defaults)
        TestLifetime.retain(player)
        let animator = LockScreenPanelAnimator()
        animator.isPresented = true
        let bounds = NSRect(x: 0, y: 0, width: 96, height: 64)
        let view = NSHostingView(rootView: ZStack {
            Color.red
            LockScreenMediaBackgroundView(artworkImage: nil, settingsViewModel: settings,
                                          nowPlayingViewModel: player, animator: animator)
        }.frame(width: bounds.width, height: bounds.height))
        let window = NSWindow(contentRect: bounds, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        defer { window.contentView = nil; window.close() }
        for step in 0..<4 {
            switch step {
            case 1: animator.expandArtwork()
            case 2: animator.toggleLyrics()
            case 3: animator.closeExpandedPlayer()
            default: break
            }
            try await Task.sleep(for: .milliseconds(360))
            view.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            for x in [2, bitmap.pixelsWide / 2, bitmap.pixelsWide - 3] {
                for y in [2, bitmap.pixelsHigh / 2, bitmap.pixelsHigh - 3] {
                    let color = try XCTUnwrap(bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                    if step == 1 || step == 2 {
                        XCTAssertLessThan(color.redComponent, 0.06, "Backdrop leaks at (\(x), \(y)) in \(animator.mode)")
                    } else {
                        XCTAssertGreaterThan(color.redComponent, 0.94, "Compact player still covers the display")
                    }
                }
            }
        }
    }

    func testCompactArtworkAndLyricsSnapshots() async throws {
        guard let destination = ProcessInfo.processInfo.environment["NOTCHFLOW_TEST_ARTIFACTS"],
              let screen = NSScreen.main else { throw XCTSkip("Snapshot export was not requested") }
        let suite = "NotchFlow.Snapshot." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(false, forKey: GeneralSettingsStorage.Keys.launchAtLogin)
        let settings = SettingsViewModel(defaults: defaults)
        settings.application.notchLanguage = .english
        settings.lockScreen.isLockScreenLyricsEnabled = true
        settings.lockScreen.mediaPanelBackgroundStyle = .animatedArtwork
        let service = FakeNowPlayingService()
        let routing = FakeAudioOutputRoutingService(routes: [AudioOutputRoute(id: 1, name: "MacBook Pro Speakers",
            transportType: kAudioDeviceTransportTypeBuiltIn, isCurrent: true)])
        let model = NowPlayingViewModel(service: service, audioOutputRouting: routing, lyricsProvider: SnapshotLyricsProvider(), favoritesStore: defaults)
        TestLifetime.retain(model)
        model.startMonitoring()
        let art = NSImage(size: NSSize(width: 300, height: 300))
        art.lockFocus()
        NSGradient(starting: .systemTeal, ending: .systemIndigo)?.draw(in: NSRect(x: 0, y: 0, width: 300, height: 300), angle: 40)
        art.unlockFocus()
        let snapshot = makeNowPlayingSnapshot(title: "Sample Song", artist: "Sample Artist", album: "Sample Album",
            duration: 240, elapsedTime: 24, playbackRate: 0, artworkData: art.tiffRepresentation)
        service.publish(snapshot)
        let lock = LockScreenManager(service: InactiveLockScreenMonitoringService(), defaults: defaults)
        let animator = LockScreenPanelAnimator()
        animator.isPresented = true
        animator.disablesTransitionAnimation = true
        let root = ZStack {
            Color(red: 0.07, green: 0.15, blue: 0.28)
            LockScreenMediaBackgroundView(artworkImage: model.artworkImage, settingsViewModel: settings,
                                          nowPlayingViewModel: model, animator: animator)
            LockScreenNowPlayingPanelView(snapshot: snapshot, artworkImage: model.artworkImage, screen: screen,
                settingsViewModel: settings, nowPlayingViewModel: model, lockScreenManager: lock, animator: animator)
        }.frame(width: 1200, height: 760)
        let view = NSHostingView(rootView: root)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1200, height: 760),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        defer { window.contentView = nil; window.close(); model.stopMonitoring() }
        view.frame = NSRect(x: 0, y: 0, width: 1200, height: 760)
        try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
        for mode in LockScreenPanelAnimator.Mode.allCases {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                switch mode {
                case .compact: animator.closeExpandedPlayer()
                case .artwork: animator.expandArtwork()
                case .lyrics: animator.toggleLyrics()
                case .lyricsWide: animator.toggleLyricsSize()
                }
            }
            model.setLyricsPresentationActive(animator.showsLyrics)
            try await Task.sleep(for: .milliseconds(700))
            view.layoutSubtreeIfNeeded()
            view.display()
            let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            XCTAssertGreaterThan(png.count, 10000)
            let name = mode.rawValue + "-snapshot.png"
            try png.write(to: URL(fileURLWithPath: destination).appendingPathComponent(name))
        }
        guard case .loaded(let lyrics) = model.lyricsState else { return XCTFail("Snapshot lyrics did not load") }
        XCTAssertEqual(lyrics.activeLineIndex(at: model.elapsedTime(at: .now)), 2)
    }
}

@MainActor
private final class SnapshotLyricsProvider: LyricsProviding {
    func lyrics(for snapshot: NowPlayingSnapshot) async throws -> TrackLyrics? {
        guard let key = snapshot.lyricsLookupKey else { return nil }
        return TrackLyrics(trackKey: key, lines: [
            LyricLine(id: 0, startTime: 0, text: "The first line"),
            LyricLine(id: 1, startTime: 10, text: "The next line"),
            LyricLine(id: 2, startTime: 20, text: "The current line"),
            LyricLine(id: 3, startTime: 30, text: "Another line follows"),
            LyricLine(id: 4, startTime: 40, text: "The final line")
        ], isSynced: true)
    }
}

/// NSHostingView may return a floating-point/extended-color bitmap. Normalize before
/// reading numeric RGB components, so HDR/color-space encoding cannot break probes.
@MainActor
func normalizedMediaTestBitmap(_ bitmap: NSBitmapImageRep) throws -> NSBitmapImageRep {
    let image = try XCTUnwrap(bitmap.cgImage)
    let context = try XCTUnwrap(CGContext(data: nil, width: image.width, height: image.height,
        bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    return NSBitmapImageRep(cgImage: try XCTUnwrap(context.makeImage()))
}
