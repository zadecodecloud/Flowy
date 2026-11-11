import IOKit.pwr_mgt
import os

/// One process-owned assertion for the visible lock-screen player. macOS releases
/// it on process exit and still honors explicit sleep and closing the lid.
final class LockScreenDisplayActivity {
    private(set) var assertionID: IOPMAssertionID?
    private let logger = Logger(subsystem: "app.notchflow.mac", category: "LockScreenMedia")

    func setActive(_ active: Bool) {
        if !active {
            if let assertionID { IOPMAssertionRelease(assertionID) }
            assertionID = nil
            return
        }
        guard assertionID == nil else { return }
        var id = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn), "Flowy lock screen player is visible" as CFString, &id)
        if result == kIOReturnSuccess {
            assertionID = id
        } else {
            logger.error("Unable to keep the lock screen display awake: \(result)")
        }
    }

    deinit {
        if let assertionID { IOPMAssertionRelease(assertionID) }
    }
}
