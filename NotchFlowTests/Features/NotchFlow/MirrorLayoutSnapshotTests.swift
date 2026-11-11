import XCTest
import SwiftUI
@testable import NotchFlow

@MainActor
final class MirrorLayoutSnapshotTests: XCTestCase {
    private var suiteName = ""

    override func tearDown() {
        if !suiteName.isEmpty {
            UserDefaults().removePersistentDomain(forName: suiteName)
            suiteName = ""
        }
        super.tearDown()
    }

    private struct Fixture {
        let content: MirrorNotchContent
        let camera: MirrorCameraController
        let settings: SettingsViewModel
    }

    private func makeFixture() throws -> Fixture {
        suiteName = "NotchFlow.MirrorSnapshot." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.set(false, forKey: GeneralSettingsStorage.Keys.launchAtLogin)
        let settings = SettingsViewModel(defaults: defaults)
        settings.application.notchLanguage = .vietnamese
        let nowPlaying = NowPlayingViewModel(service: FakeNowPlayingService(), favoritesStore: defaults)
        TestLifetime.retain(nowPlaying)
        let camera = MirrorCameraController(capture: FakeMirrorCapture(), settings: settings.mediaAndFiles)
        let content = MirrorNotchContent(camera: camera, nowPlaying: nowPlaying, settings: settings,
                                         selectPage: { _ in }, close: {})
        return Fixture(content: content, camera: camera, settings: settings)
    }

    /// Note: `glassEffect` controls do not rasterize through `ImageRenderer`, so the
    /// header's glass buttons are absent from these snapshots by design, as is the
    /// notch's own glass backdrop. Non-glass chrome (the page pager) does render.
    private func render(_ content: MirrorNotchContent, settings: SettingsViewModel,
                        size: CGSize) throws -> Data {
        let root = ZStack(alignment: .top) {
            LinearGradient(colors: [.init(red: 0.12, green: 0.24, blue: 0.28), .black],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            NotchBackgroundSurface(isExpanded: true, style: .glass, glassTransparency: 0.78,
                topCornerRadius: 24, bottomCornerRadius: 34, isDynamicIsland: false,
                dynamicIslandCornerRadius: 0, strokeColor: .clear)
                .overlay { content.expandedView() }
                .frame(width: size.width, height: size.height)
        }
        .environment(\.colorScheme, .dark)
        .environment(\.locale, settings.application.notchLanguage.locale)
        .frame(width: 900, height: 660)
        let renderer = ImageRenderer(content: root)
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage)
        return try XCTUnwrap(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
    }

    /// Layout contract. Runs on every test pass, with or without artifact export.
    func testExpandedGeometryIsStableAcrossNotchSizes() throws {
        let fixture = try makeFixture()
        let content = fixture.content

        // Floors hold for a small notch, and the notch size still widens the surface.
        XCTAssertEqual(content.expandedSize(baseWidth: 190, baseHeight: 38), CGSize(width: 560, height: 443))
        XCTAssertEqual(content.expandedSize(baseWidth: 0, baseHeight: 0), CGSize(width: 560, height: 440))
        XCTAssertEqual(content.expandedSize(baseWidth: 300, baseHeight: 60), CGSize(width: 640, height: 465))
        // Dynamic Island presentation matches the notch presentation.
        XCTAssertEqual(content.expandedDynamicIslandSize(baseWidth: 190, baseHeight: 38),
                       content.expandedSize(baseWidth: 190, baseHeight: 38))

        XCTAssertEqual(content.compactSize(baseWidth: 190, baseHeight: 38), CGSize(width: 260, height: 38))
        let radii = content.expandedCornerRadius(baseRadius: 10)
        XCTAssertEqual(radii.top, 24)
        XCTAssertEqual(radii.bottom, NotchPageMetrics.bottomCornerRadius)
        XCTAssertTrue(content.isExpandable)
        XCTAssertFalse(content.usesContentResizeEffect)
        XCTAssertEqual(content.id, NotchContentRegistry.Mirror.preview.id)
        XCTAssertEqual(content.id, NotchPage.mirror.contentID)
    }

    /// Rendering the view must never bring the camera up.
    func testRenderingEveryStateNeverActivatesTheCamera() throws {
        let fixture = try makeFixture()
        let size = fixture.content.expandedSize(baseWidth: 190, baseHeight: 38)

        let png = try render(fixture.content, settings: fixture.settings, size: size)
        XCTAssertGreaterThan(png.count, 10_000)
        XCTAssertEqual(fixture.camera.state, .inactive, "Rendering a preview must never activate the camera")

        // Compact presentation renders too.
        XCTAssertNoThrow(try render(fixture.content, settings: fixture.settings,
                                    size: fixture.content.compactSize(baseWidth: 190, baseHeight: 38)))
        XCTAssertEqual(fixture.camera.state, .inactive)
    }

    func testSnapshotExportWritesPreviewWhenRequested() throws {
        guard let destination = ProcessInfo.processInfo.environment["NOTCHFLOW_TEST_ARTIFACTS"] else {
            throw XCTSkip("Snapshot export not requested")
        }
        let fixture = try makeFixture()
        let size = fixture.content.expandedSize(baseWidth: 190, baseHeight: 38)
        try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
        let png = try render(fixture.content, settings: fixture.settings, size: size)
        try png.write(to: URL(fileURLWithPath: destination)
            .appendingPathComponent("mirror-implementation-preview.png"))
    }

    /// The fork ships English and Vietnamese for its own keys; both must resolve.
    func testMirrorStringsResolveInShippedLanguages() {
        let keys = [
            "notchflow.mirror.title", "notchflow.mirror.frontCamera", "notchflow.mirror.flip",
            "notchflow.mirror.close", "notchflow.mirror.starting", "notchflow.mirror.requesting",
            "notchflow.mirror.denied", "notchflow.mirror.interrupted", "notchflow.mirror.unavailable",
            "notchflow.mirror.openSettings", "notchflow.mirror.retry",
            "notchflow.mirror.tab.music", "notchflow.mirror.tab.tray", "notchflow.page.mirror",
            "settings.section.mirror.title", "settings.section.mirror.subtitle",
            "settings.mirror.card.activity", "settings.mirror.card.appearance",
            "settings.mirror.liveActivity.title", "settings.mirror.liveActivity.desc",
            "settings.mirror.flipped.title", "settings.mirror.flipped.desc"
        ]
        for language in [NotchLanguage.english, .vietnamese] {
            for key in keys {
                let value = L10n.string(key, language: language)
                XCTAssertNotEqual(value, key, "\(key) is unresolved in \(language.rawValue)")
                XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                               "\(key) is empty in \(language.rawValue)")
            }
        }
    }

    func testMirrorSectionIsListedUnderPages() {
        let section = SettingsRootViewModel.Section.mirror
        XCTAssertEqual(section.sidebarGroup, .pages)
        XCTAssertEqual(section.resetGroup, .mirror)
        XCTAssertEqual(section.accessibilityIdentifier, "settings.tab.mirror")
        XCTAssertTrue(SettingsRootViewModel.Section.allCases.contains(.mirror))
        XCTAssertEqual(SettingsRootViewModel.Section.initialSelection(storedValue: "mirror"), .mirror)
        XCTAssertEqual(SettingsRootViewModel.Section.initialSelection(storedValue: "camera"), .mirror)
    }
}
