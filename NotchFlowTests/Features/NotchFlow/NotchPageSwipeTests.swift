import XCTest
import AppKit
@testable import NotchFlow

final class NotchPageSwipeTests: XCTestCase {
    func testOrderedPagesSkipUnavailableFeatures() {
        let all: [NotchPage] = [.media, .tray, .mirror]
        XCTAssertEqual(NotchPage.adjacent(to: .media, direction: .right, available: all), .tray)
        XCTAssertEqual(NotchPage.adjacent(to: .tray, direction: .right, available: all), .mirror)
        XCTAssertEqual(NotchPage.adjacent(to: .mirror, direction: .left, available: all), .tray)
        XCTAssertNil(NotchPage.adjacent(to: .mirror, direction: .right, available: all))
        XCTAssertEqual(NotchPage.adjacent(to: .media, direction: .right, available: [.media, .mirror]), .mirror)
    }

    func testFileScrollOwnsGestureUntilNextSwipeAndPagingWorksAtEdges() {
        let document = CGRect(x: 0, y: 0, width: 900, height: 100)
        let middle = CGRect(x: 300, y: 0, width: 300, height: 100)
        let left = CGRect(x: 0, y: 0, width: 300, height: 100)
        let right = CGRect(x: 600, y: 0, width: 300, height: 100)
        XCTAssertTrue(NotchPageGestureArbiter.canScroll(deltaX: 10, visible: middle, document: document))
        XCTAssertTrue(NotchPageGestureArbiter.canScroll(deltaX: -10, visible: middle, document: document))
        XCTAssertFalse(NotchPageGestureArbiter.canScroll(deltaX: 10, visible: left, document: document))
        XCTAssertFalse(NotchPageGestureArbiter.canScroll(deltaX: -10, visible: right, document: document))
        var arbiter = NotchPageGestureArbiter()
        XCTAssertFalse(arbiter.usePage(starts: true, momentum: false, x: 10, y: 0, canScroll: true))
        XCTAssertFalse(arbiter.usePage(starts: false, momentum: false, x: 40, y: 0, canScroll: false))
        XCTAssertFalse(arbiter.usePage(starts: false, momentum: true, x: 5, y: 0, canScroll: false))
        XCTAssertTrue(arbiter.usePage(starts: true, momentum: false, x: 10, y: 0, canScroll: false))
    }

    func testGestureRequiresHorizontalIntentAndOnlyFiresOnce() {
        var swipe = NotchPageSwipe()
        XCTAssertNil(swipe.update(x: 10, y: 30))
        XCTAssertNil(swipe.update(x: 30, y: 30))
        XCTAssertNil(swipe.update(x: 30, y: 20))
        swipe.reset()
        XCTAssertNil(swipe.update(x: 30, y: 2))
        XCTAssertEqual(swipe.update(x: 32, y: 2), .right)
        XCTAssertNil(swipe.update(x: 90, y: 0))
        swipe.reset()
        XCTAssertEqual(swipe.update(x: -65, y: 2), .left)
    }

    func testPageSwipeStartsAcrossEntireNotchAndOnlyChangesPageOnce() {
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 200)
        for point in [CGPoint(x: 12, y: 12), CGPoint(x: 388, y: 12),
                      CGPoint(x: 200, y: 100), CGPoint(x: 12, y: 188), CGPoint(x: 388, y: 188)] {
            for delta: CGFloat in [-65, 65] {
                var gesture = NotchPageSwipeTracking()
                let first = gesture.update(location: point, bounds: bounds, x: delta, y: 1,
                                           starts: true, ends: false, momentum: false)
                XCTAssertEqual(first.direction, delta > 0 ? .right : .left, "Starting at \(point)")
                XCTAssertTrue(first.consumes)
                let continued = gesture.update(location: point, bounds: bounds, x: delta, y: 0,
                                               starts: false, ends: false, momentum: false)
                XCTAssertNil(continued.direction)
                XCTAssertTrue(continued.consumes)
            }
        }
    }

    func testPageSwipeLeavesOutsideAndVerticalGesturesToTheirOwnViews() {
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 200)
        var gesture = NotchPageSwipeTracking()
        let outside = gesture.update(location: CGPoint(x: 200, y: 201), bounds: bounds, x: 80, y: 0,
                                     starts: true, ends: false, momentum: false)
        XCTAssertFalse(outside.consumes)
        XCTAssertNil(outside.direction)
        let vertical = gesture.update(location: CGPoint(x: 200, y: 100), bounds: bounds, x: 2, y: 30,
                                      starts: true, ends: false, momentum: false)
        XCTAssertFalse(vertical.consumes)
        let diagonalTail = gesture.update(location: .zero, bounds: bounds, x: 120, y: 0,
                                          starts: false, ends: false, momentum: false)
        XCTAssertFalse(diagonalTail.consumes)
        XCTAssertNil(diagonalTail.direction)
    }

    func testHorizontalGestureConsumesItsTailAndMomentumThenResets() {
        var gesture = NotchPageSwipeTracking()
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 200)
        let first = gesture.update(location: CGPoint(x: 200, y: 180), bounds: bounds, x: 20, y: 1,
                                   starts: true, ends: false, momentum: false)
        XCTAssertTrue(first.consumes)
        XCTAssertNil(first.direction)
        let end = gesture.update(location: .zero, bounds: bounds, x: 0, y: 0,
                                 starts: false, ends: true, momentum: false)
        XCTAssertTrue(end.consumes)
        let inertia = gesture.update(location: .zero, bounds: bounds, x: 100, y: 0,
                                     starts: false, ends: false, momentum: true)
        XCTAssertTrue(inertia.consumes)
        XCTAssertNil(inertia.direction)
        let newVertical = gesture.update(location: .zero, bounds: bounds, x: 0, y: 50,
                                         starts: true, ends: false, momentum: false)
        XCTAssertFalse(newVertical.consumes)
    }

    @MainActor
    func testSelectedTraySurvivesMediaUpdatesAndCriticalActivityPreemptsIt() async {
        let vm = NotchViewModel(settings: TestNotchSettings(), hideDelay: 0.01, queueDelay: 0)
        TestLifetime.retain(vm)
        let music = TestNotchContent(id: NotchContentRegistry.Media.nowPlaying.id, priority: 8, isExpandable: true)
        let tray = TestNotchContent(id: NotchContentRegistry.DragAndDrop.trayActive.id, priority: 6, isExpandable: true)
        vm.send(.showLiveActivity(music))
        await assertEventually { await MainActor.run { vm.notchModel.content?.id == music.id } }
        vm.selectPage(tray)
        await assertEventually { await MainActor.run { vm.notchModel.content?.id == tray.id && vm.notchModel.isExpanded } }
        vm.send(.showLiveActivity(music))
        vm.send(.showLiveActivity(TestNotchContent(id: "critical", priority: 10003)))
        await assertEventually { await MainActor.run { vm.notchModel.content?.id == "critical" } }
        vm.send(.hideLiveActivity(id: "critical"))
        await assertEventually { await MainActor.run { vm.notchModel.content?.id == tray.id } }
        vm.selectPage(music)
        await assertEventually { await MainActor.run { vm.notchModel.content?.id == music.id && vm.notchModel.isExpanded } }
        vm.send(.hideLiveActivity(id: music.id))
        await assertEventually { await MainActor.run { vm.notchModel.content?.id == tray.id } }
    }
}
