import XCTest
@testable import NotchFlow

final class ScrollingTextTests: XCTestCase {
    func testRestsThenScrollsOneFullCycleAndRepeats() {
        let width: CGFloat = 300, gap: CGFloat = 40, speed: CGFloat = 30, pause = 1.6
        func x(_ t: TimeInterval) -> CGFloat { ScrollingText.offset(elapsed: t, textWidth: width, gap: gap, speed: speed, pause: pause) }
        XCTAssertEqual(x(0), 0)
        XCTAssertEqual(x(1.5), 0, "Rests before moving")
        XCTAssertEqual(x(pause + 2), -60, accuracy: 0.001, "Moves at the set speed")
        let period = pause + Double((width + gap) / speed)
        XCTAssertEqual(x(period), 0, accuracy: 0.001, "Loops back to the start")
        XCTAssertEqual(x(period + pause + 1), x(pause + 1), accuracy: 0.001)
        XCTAssertEqual(ScrollingText.offset(elapsed: 5, textWidth: 0, gap: gap, speed: speed, pause: pause), 0)
    }

    func testLockScreenBackgroundMovesSlowerThanBefore() {
        XCTAssertLessThan(LockScreenAmbientMesh.motionPace, 1)
        XCTAssertEqual(LockScreenAmbientMesh.fields(at: 10), LockScreenAmbientMesh.fields(at: 10))
        XCTAssertNotEqual(LockScreenAmbientMesh.fields(at: 0), LockScreenAmbientMesh.fields(at: 3))
    }
}
