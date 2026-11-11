import XCTest
@testable import NotchFlow

final class LockScreenMonitoringTests: XCTestCase {
    func testLaunchWhileLockedAndMissedUnlockAreReconciledOnce() {
        var state: Bool? = true
        let service = DistributedLockScreenMonitoringService(reconciliationInterval: 60, queryLockState: { state })
        var values: [Bool] = []
        service.onLockStateChange = { values.append($0) }
        service.startMonitoring()
        service.startMonitoring()
        service.reconcileState()
        XCTAssertEqual(values, [true])
        state = nil
        service.reconcileState()
        XCTAssertEqual(values, [true], "Unknown session must not be interpreted as unlocked")
        state = false
        service.reconcileState()
        XCTAssertEqual(values, [true, false])
        service.stopMonitoring()
        state = true
        service.reconcileState()
        XCTAssertEqual(values, [true, false])
        service.startMonitoring()
        XCTAssertEqual(values, [true, false, true])
        service.stopMonitoring()
    }
}
