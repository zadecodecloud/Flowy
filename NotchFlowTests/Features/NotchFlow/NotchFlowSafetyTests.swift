import XCTest
@testable import NotchFlow

final class NotchFlowSafetyTests: XCTestCase {
    @MainActor
    func testFaceScanCannotSucceed() {
        let service = FaceIDService()
        var result: Bool?
        service.startScan { result = $0 }
        XCTAssertEqual(result, false)
        XCTAssertTrue(service.state.isFailed)
        service.cancelScan()
        XCTAssertEqual(service.state, .idle)
    }

    func testUpdatesAreUnconfigured() {
        let updater = SparkleUpdater.shared
        XCTAssertFalse(updater.canCheckForUpdates)
        XCTAssertFalse(updater.automaticallyChecksForUpdates)
        XCTAssertFalse(updater.automaticallyDownloadsUpdates)
        updater.checkForUpdates()
        XCTAssertFalse(updater.isUpdateAvailable)
    }
}
