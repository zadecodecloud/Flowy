import XCTest
@testable import NotchFlow

final class ScreenshotStagingDirectoryTests: XCTestCase {
    private let own = URL(fileURLWithPath: "/tmp/caches/app.notchflow.mac/RawScreenshots")

    func testLeftoverStagingFolderIsReadSoScreenshotsAreNotLost() {
        let legacy = "/Users/me/Library/Caches/com.Jackson.DynamicNotch/RawScreenshots"
        XCTAssertEqual(ScreenshotMonitorService.stagingDirectory(systemLocation: legacy, ownDefault: own).path, legacy)
    }

    func testUserChosenFolderIsNotTreatedAsStaging() {
        XCTAssertEqual(ScreenshotMonitorService.stagingDirectory(systemLocation: "~/Desktop", ownDefault: own), own)
        XCTAssertEqual(ScreenshotMonitorService.stagingDirectory(systemLocation: "/Users/me/RawScreenshots Archive", ownDefault: own), own)
    }

    func testNoSystemLocationUsesOwnFolder() {
        XCTAssertEqual(ScreenshotMonitorService.stagingDirectory(systemLocation: nil, ownDefault: own), own)
        XCTAssertEqual(ScreenshotMonitorService.stagingDirectory(systemLocation: "", ownDefault: own), own)
    }
}
