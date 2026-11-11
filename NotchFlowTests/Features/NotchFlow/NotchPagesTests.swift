import XCTest
import SwiftUI
@testable import NotchFlow

final class NotchPagesTests: XCTestCase {
    func testPageIndicatorStaysVisibleWhileAPageIsOpen() {
        let pages: [NotchPage] = [.media, .tray, .mirror]
        XCTAssertTrue(NotchPageIndicator.isShown(pages: pages, current: .mirror, isExpanded: true),
                      "No auto-hide: visible for as long as the page is open")
        XCTAssertFalse(NotchPageIndicator.isShown(pages: pages, current: .mirror, isExpanded: false), "Never on a compact notch")
        XCTAssertFalse(NotchPageIndicator.isShown(pages: [.mirror], current: .mirror, isExpanded: true), "Nothing to switch to")
        XCTAssertFalse(NotchPageIndicator.isShown(pages: pages, current: nil, isExpanded: true), "Not over non-page activities")
    }

    @MainActor
    func testClickingAnEmptyNotchAsksForTheDefaultPage() {
        let settings = TestNotchSettings()
        let vm = NotchViewModel(settings: settings, hideDelay: 0.01, queueDelay: 0)
        TestLifetime.retain(vm)
        var requests = 0
        vm.onIdleTap = { requests += 1 }
        vm.handleIdleTap()
        XCTAssertEqual(requests, 1)
        vm.isLocked = true
        vm.handleIdleTap()
        XCTAssertEqual(requests, 1, "Never on the lock screen")
    }

    func testOnlyShortStillClicksCountAsNotchTaps() {
        let p = NSPoint(x: 756, y: 970)
        XCTAssertTrue(AppDelegate.isIdleNotchClick(start: p, end: NSPoint(x: 760, y: 966), duration: 0.12))
        XCTAssertFalse(AppDelegate.isIdleNotchClick(start: p, end: NSPoint(x: 790, y: 970), duration: 0.12), "A drag is not a click")
        XCTAssertFalse(AppDelegate.isIdleNotchClick(start: p, end: p, duration: 1.2), "A long press is not a click")
    }

    func testPageIndicatorStaysInsideTheBandBesideTheCamera() {
        // Mirror page on a 14" MacBook Pro: 560 wide, 201 pt camera band, 24 pt shoulders.
        let wing = NotchPageIndicator.wingWidth(notchWidth: 560, cameraBandWidth: 201, topCornerRadius: 24)
        XCTAssertEqual(wing, 147.5, accuracy: 0.01)
        XCTAssertLessThanOrEqual(24 + 4 + wing, (560 - 201) / 2, "Left wing must end before the camera band")
        XCTAssertEqual(NotchPageIndicator.wingWidth(notchWidth: 180, cameraBandWidth: 201, topCornerRadius: 24), 0)
    }

    func testEveryPageSitsTheSameDistanceInsideTheNotchWalls() {
        for radius: CGFloat in [24, 34] {
            let padding = NotchPageMetrics.horizontalPadding(topCornerRadius: radius, isNotchless: false)
            XCTAssertEqual(padding - radius, NotchPageMetrics.innerMargin)
        }
        XCTAssertEqual(NotchPageMetrics.horizontalPadding(topCornerRadius: 24, isNotchless: true),
                       NotchPageMetrics.notchlessHorizontalPadding)
    }

    @MainActor
    func testMirrorZoomIsClampedAndGrowsThePreviewAroundItsCentre() {
        let camera = MirrorCameraController(capture: FakeMirrorCapture())
        camera.zoom = 3
        XCTAssertEqual(camera.zoom, 2)
        camera.zoom = 0.2
        XCTAssertEqual(camera.zoom, 1)
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 250)
        XCTAssertEqual(MirrorPreviewContainer.zoomedFrame(bounds, zoom: 1), bounds)
        let zoomed = MirrorPreviewContainer.zoomedFrame(bounds, zoom: 2)
        XCTAssertEqual(zoomed.size, CGSize(width: 800, height: 500))
        XCTAssertEqual(zoomed.midX, bounds.midX)
        XCTAssertEqual(zoomed.midY, bounds.midY)
        XCTAssertFalse(camera.isRingLightOn, "Ring light starts off")
    }

    @MainActor
    func testSelectedMirrorSurvivesMediaUpdates() async {
        let vm = NotchViewModel(settings: TestNotchSettings(), hideDelay: 0.01, queueDelay: 0)
        TestLifetime.retain(vm)
        let music = TestNotchContent(id: NotchContentRegistry.Media.nowPlaying.id, priority: 8, isExpandable: true)
        let mirror = TestNotchContent(id: NotchContentRegistry.Mirror.preview.id, priority: 8, isExpandable: true)
        vm.send(.showLiveActivity(music))
        await assertEventually { await MainActor.run { vm.notchModel.content?.id == music.id } }
        vm.selectPage(mirror)
        await assertEventually { await MainActor.run { vm.notchModel.content?.id == mirror.id && vm.notchModel.isExpanded } }
        for _ in 0..<3 { vm.send(.showLiveActivity(music)) }
        try? await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(vm.notchModel.content?.id, mirror.id, "Playback updates must not take the page back")
    }

    func testMirrorUsesTheApprovedWideLayout() {
        XCTAssertEqual(MirrorLayout.topCornerRadius, 24)
        XCTAssertEqual(MirrorLayout.spacing, NotchPageMetrics.blockSpacing)
        XCTAssertEqual(MirrorLayout.bottomPadding, NotchPageMetrics.innerMargin)
    }
}
