import XCTest
import AppKit
@testable import DynamicNotch

/// Opt-in integration check against the real WindowServer, with a fully transparent, noninteractive test panel.
@MainActor
final class SkyLightNativeDelegationTests: XCTestCase {
    func testTransparentPanelActuallyJoinsLockScreenSpace() async throws {
        guard ProcessInfo.processInfo.environment["NOTCHFLOW_NATIVE_WINDOW_TEST"] == "1" else {
            throw XCTSkip("Native WindowServer integration is opt-in")
        }
        let window = OverlayPanelFactory.makeLockScreenBackground(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        defer { window.orderOut(nil); window.close() }
        // Realize the WindowServer window without displaying content or receiving input.
        window.alphaValue = 0
        window.orderFrontRegardless()
        let bridge = SkyLightOperator.shared
        XCTAssertTrue(bridge.isAvailable)
        XCTAssertTrue(bridge.delegateWindow(window, to: .lockScreenOverlay))
        var membership: Bool?
        for _ in 0..<30 {
            membership = bridge.isWindowDelegated(window, to: .lockScreenOverlay)
            if membership == true { break }
            try await Task.sleep(for: .milliseconds(30))
        }
        print("Native membership: " + bridge.delegationDiagnostic(window, to: .lockScreenOverlay))
        XCTAssertEqual(membership, true, "WindowServer must report actual membership, independently of a native return register")
        XCTAssertEqual(window.alphaValue, 0)
        XCTAssertTrue(window.ignoresMouseEvents)
        XCTAssertFalse(window.canBecomeKey)
        window.orderOut(nil)
        XCTAssertFalse(window.isVisible)
    }
}
