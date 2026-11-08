import XCTest
import IOKit.pwr_mgt
@testable import DynamicNotch

final class LockScreenDisplayActivityTests: XCTestCase {
    func testOneNativeDisplayAssertionAcrossRepeatedUpdatesAndRelease() throws {
        let activity = LockScreenDisplayActivity()
        defer { activity.setActive(false) }
        XCTAssertNil(activity.assertionID)
        activity.setActive(true)
        let first = try XCTUnwrap(activity.assertionID)
        XCTAssertNotNil(IOPMAssertionCopyProperties(first)?.takeRetainedValue())
        activity.setActive(true)
        XCTAssertEqual(activity.assertionID, first)
        activity.setActive(false)
        XCTAssertNil(activity.assertionID)
        XCTAssertNil(IOPMAssertionCopyProperties(first)?.takeRetainedValue())
        activity.setActive(false)
    }
}
