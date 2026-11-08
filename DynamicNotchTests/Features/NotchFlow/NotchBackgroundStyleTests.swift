import XCTest
import SwiftUI
import AppKit
@testable import DynamicNotch

final class NotchBackgroundStyleTests: XCTestCase {
    func testGlassPreferenceRoundTripsAndUnknownFallsBackToBlack() {
        XCTAssertEqual(NotchBackgroundStyle.resolved("glass"), .glass)
        XCTAssertEqual(NotchBackgroundStyle.resolved("black"), .black)
        XCTAssertEqual(NotchBackgroundStyle.resolved("unknown"), .black)
        XCTAssertEqual(NotchBackgroundStyle.resolved(nil), .black)
    }

    @MainActor
    func testGlassSliderChangesOnlyTheLowerHalfIncludingBothEndpoints() {
        for value in [0.0, 0.5, 0.85, 1.0] {
            let profile = NotchGlassProfile(transparency: value)
            for y in stride(from: 0.0, through: 0.5, by: 0.05) {
                XCTAssertEqual(profile.transmission(at: y), 0)
            }
            XCTAssertEqual(profile.transmission(at: 1), value, accuracy: 0.0001)
            XCTAssertEqual(profile.transmission(at: 0.71), value / 2, accuracy: 0.001)
        }
    }

    func testReduceTransparencyUsesOpaqueBlackWithoutChangingSavedChoice() {
        let preference = NotchBackgroundStyle.glass
        XCTAssertEqual(preference.effectiveStyle(reduceTransparency: true), .black)
        XCTAssertEqual(preference.effectiveStyle(reduceTransparency: false), .glass)
    }

    @MainActor
    func testCompactSurfaceIsBlackEvenWithFullGlassAndAnEnabledStroke() throws {
        for island in [false, true] {
            for style in NotchBackgroundStyle.allCases {
                let surface = NotchBackgroundSurface(isExpanded: false, style: style, glassTransparency: 1,
                    topCornerRadius: 8, bottomCornerRadius: 10, isDynamicIsland: island,
                    dynamicIslandCornerRadius: 12, strokeColor: .red, strokeWidth: 6)
                    .frame(width: 160, height: 40)
                    .background(Color.green)
                let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(ImageRenderer(content: surface).cgImage))
                // The end samples also catch a compact stroke or lower-rim highlight.
                for y in [1, 10, 20, 30, 38] {
                    let color = try XCTUnwrap(bitmap.colorAt(x: 80, y: y)?.usingColorSpace(.sRGB))
                    XCTAssertLessThan(max(color.redComponent, color.greenComponent, color.blueComponent), 0.02)
                    XCTAssertGreaterThan(color.alphaComponent, 0.99)
                }
                let outside = try XCTUnwrap(bitmap.colorAt(x: 0, y: 38)?.usingColorSpace(.sRGB))
                XCTAssertGreaterThan(outside.greenComponent, 0.5)
            }
        }
    }

    @MainActor
    func testExpandedNativeGlassPreservesBackdropColorWhileTopStaysBlack() async throws {
        // cacheDisplay can omit WindowServer backdrop sampling entirely. Calibrate
        // against an unmodified system glass view before judging the app's surface.
        var calibration: [NSColor] = []
        for color in [Color.red, Color.blue] {
            let host = NSHostingView(rootView: ZStack {
                color
                Color.clear.frame(width: 80, height: 80).glassEffect(.clear, in: Rectangle())
            }.frame(width: 100, height: 100))
            host.frame = NSRect(x: 0, y: 0, width: 100, height: 100)
            host.layoutSubtreeIfNeeded()
            var bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            bitmap = try normalizedMediaTestBitmap(bitmap)
            calibration.append(try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2)?.usingColorSpace(.sRGB)))
        }
        guard abs(calibration[0].redComponent - calibration[1].redComponent) > 0.2 else {
            throw XCTSkip("NSView bitmap rendering cannot sample the backdrop even for unmodified Apple clear glass; requires WindowServer visual verification")
        }
        var samples: [NSColor] = []
        for color in [Color.red, Color.blue] {
            let host = NSHostingView(rootView: ZStack {
                color
                SurfaceResizeFixture(expanded: true)
            }.environment(\.colorScheme, .dark).frame(width: 500, height: 300))
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
                                  styleMask: .borderless, backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            defer { window.contentView = nil; window.close() }
            try await Task.sleep(for: .milliseconds(100))
            host.layoutSubtreeIfNeeded()
            var bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            bitmap = try normalizedMediaTestBitmap(bitmap)
            if let directory = ProcessInfo.processInfo.environment["NOTCHFLOW_TEST_ARTIFACTS"] {
                let url = URL(fileURLWithPath: directory).appendingPathComponent("notch-glass-\(samples.count).png")
                try bitmap.representation(using: .png, properties: [:])?.write(to: url)
            }
            let scale = CGFloat(bitmap.pixelsWide) / 500
            let top = try XCTUnwrap(bitmap.colorAt(x: Int(250 * scale), y: Int(30 * scale))?.usingColorSpace(.sRGB))
            XCTAssertLessThan(max(top.redComponent, top.greenComponent, top.blueComponent), 0.04)
            samples.append(try XCTUnwrap(bitmap.colorAt(x: Int(250 * scale), y: Int(150 * scale))?.usingColorSpace(.sRGB)))
        }
        XCTAssertGreaterThan(samples[0].redComponent - samples[1].redComponent, 0.3,
                             "An opaque glass surface hides the red backdrop")
        XCTAssertGreaterThan(samples[1].blueComponent - samples[0].blueComponent, 0.3,
                             "An opaque glass surface hides the blue backdrop")
    }

    @MainActor
    func testGlassSelectionPersistsAndResetReturnsToClearGlass() throws {
        let suite = "NotchFlow.GlassTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = ApplicationSettingsStore(defaults: defaults)
        XCTAssertEqual(settings.notchBackgroundStyle, .glass)
        settings.notchBackgroundStyle = .glass
        settings.notchGlassTransparency = 0.8
        XCTAssertEqual(defaults.string(forKey: GeneralSettingsStorage.Keys.notchBackgroundStyle), "glass")
        XCTAssertEqual(ApplicationSettingsStore(defaults: defaults).notchBackgroundStyle, .glass)
        XCTAssertEqual(ApplicationSettingsStore(defaults: defaults).notchGlassTransparency, 0.8, accuracy: 0.001)
        settings.notchGlassTransparency = 2
        XCTAssertEqual(settings.notchGlassTransparency, 1)
        settings.notchGlassTransparency = -1
        XCTAssertEqual(settings.notchGlassTransparency, 0)
        settings.resetNotch()
        XCTAssertEqual(settings.notchBackgroundStyle, .glass)
        XCTAssertEqual(settings.notchGlassTransparency, 0.78, accuracy: 0.001)
    }

    @MainActor
    func testClearGlassMigrationRunsOnceAndPreservesLaterPreferences() throws {
        let suite = "NotchFlow.GlassMigration." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("black", forKey: GeneralSettingsStorage.Keys.notchBackgroundStyle)
        defaults.set(0.5, forKey: GeneralSettingsStorage.Keys.notchGlassTransparency)
        ApplicationSettingsStore.migrateCrystalGlassAppearance(defaults: defaults)
        XCTAssertEqual(defaults.string(forKey: GeneralSettingsStorage.Keys.notchBackgroundStyle), "glass")
        XCTAssertEqual(defaults.double(forKey: GeneralSettingsStorage.Keys.notchGlassTransparency), 0.78)
        XCTAssertEqual(LockScreenSettings.widgetAppearanceStyle(in: defaults), .liquidGlass)
        defaults.set("black", forKey: GeneralSettingsStorage.Keys.notchBackgroundStyle)
        defaults.set(0.9, forKey: GeneralSettingsStorage.Keys.notchGlassTransparency)
        ApplicationSettingsStore.migrateCrystalGlassAppearance(defaults: defaults)
        XCTAssertEqual(defaults.string(forKey: GeneralSettingsStorage.Keys.notchBackgroundStyle), "black")
        XCTAssertEqual(defaults.double(forKey: GeneralSettingsStorage.Keys.notchGlassTransparency), 0.9)
    }

    @MainActor
    func testGlassBackdropSamplesBehindWindowAndDoesNotCaptureClicks() {
        if #available(macOS 26.0, *) {
            let view = NotchGlassBackdropView(frame: NSRect(x: 0, y: 0, width: 240, height: 40))
            XCTAssertEqual(view.backdrop.blendingMode, .behindWindow)
            XCTAssertEqual(view.backdrop.state, .active)
            XCTAssertEqual(view.glass.style, .clear)
            XCTAssertEqual(view.backdrop.alphaValue, 0)
            XCTAssertTrue(view.backdrop.isHidden)
            XCTAssertEqual(view.glass.style, .clear)
            XCTAssertNil(view.glass.tintColor)
            if #available(macOS 27.0, *) { XCTAssertFalse(view.glass.effectIsInteractive) }
            XCTAssertNil(view.hitTest(NSPoint(x: 10, y: 10)))
        }
    }
}

private struct SurfaceResizeFixture: View {
    let expanded: Bool
    var body: some View {
        NotchBackgroundSurface(isExpanded: expanded, style: .glass, glassTransparency: 1,
            topCornerRadius: expanded ? 20 : 8, bottomCornerRadius: expanded ? 30 : 12,
            isDynamicIsland: false, dynamicIslandCornerRadius: 0, strokeColor: .clear)
            .frame(width: expanded ? 384 : 260, height: expanded ? 198 : 38, alignment: .top)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
