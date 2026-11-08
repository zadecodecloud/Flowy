import AVFoundation
import XCTest
@testable import DynamicNotch

/// Capture double. Nothing here touches AVFoundation, so no test can reach the
/// camera or raise a TCC prompt.
final class FakeMirrorCapture: MirrorCaptureControlling, @unchecked Sendable {
    var authorizationToReturn: AVAuthorizationStatus = .authorized
    var startResult: MirrorCaptureStartResult = .running
    var accessGranted = true
    /// When true, `start` parks its completion in `pendingStart` instead of finishing.
    var holdsStart = false
    /// When true, `requestAuthorization` parks its completion instead of answering.
    var holdsAuthorization = false

    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var authorizationRequestCount = 0
    var pendingStart: (@Sendable (MirrorCaptureStartResult) -> Void)?
    var pendingAuthorization: (@Sendable (Bool) -> Void)?
    private var eventHandler: (@Sendable (MirrorCaptureEvent) -> Void)?

    var previewSession: AVCaptureSession? { nil }
    var authorization: AVAuthorizationStatus { authorizationToReturn }

    func requestAuthorization(completion: @escaping @Sendable (Bool) -> Void) {
        authorizationRequestCount += 1
        if holdsAuthorization { pendingAuthorization = completion } else { completion(accessGranted) }
    }

    func observeEvents(_ handler: @escaping @Sendable (MirrorCaptureEvent) -> Void) {
        eventHandler = handler
    }

    func start(completion: @escaping @Sendable (MirrorCaptureStartResult) -> Void) {
        startCount += 1
        if holdsStart { pendingStart = completion } else { completion(startResult) }
    }

    func stop() { stopCount += 1 }

    func emit(_ event: MirrorCaptureEvent) { eventHandler?(event) }

    func finishPendingStart(_ result: MirrorCaptureStartResult) {
        let completion = pendingStart
        pendingStart = nil
        completion?(result)
    }

    func finishPendingAuthorization(_ granted: Bool) {
        let completion = pendingAuthorization
        pendingAuthorization = nil
        completion?(granted)
    }
}

@MainActor
final class MirrorCameraControllerTests: XCTestCase {
    private var suiteName = ""

    private func makeStore() throws -> MediaAndFilesSettingsStore {
        suiteName = "NotchFlow.MirrorController." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        return MediaAndFilesSettingsStore(defaults: defaults)
    }

    override func tearDown() {
        if !suiteName.isEmpty {
            UserDefaults().removePersistentDomain(forName: suiteName)
            suiteName = ""
        }
        super.tearDown()
    }

    // MARK: - Starting

    func testAuthorizedActivationReachesRunning() async {
        let capture = FakeMirrorCapture()
        let camera = MirrorCameraController(capture: capture)
        XCTAssertEqual(camera.state, .inactive)
        camera.setActive(true)
        await assertEventually { await MainActor.run { camera.state == .running } }
        XCTAssertEqual(capture.startCount, 1)
    }

    func testMissingDeviceReportsUnavailable() async {
        let capture = FakeMirrorCapture()
        capture.startResult = .noDevice
        let camera = MirrorCameraController(capture: capture)
        camera.setActive(true)
        await assertEventually { await MainActor.run { camera.state == .unavailable } }
    }

    func testFailedSessionReportsUnavailable() async {
        let capture = FakeMirrorCapture()
        capture.startResult = .failed
        let camera = MirrorCameraController(capture: capture)
        camera.setActive(true)
        await assertEventually { await MainActor.run { camera.state == .unavailable } }
    }

    func testRepeatedActivationDoesNotRestartSession() async {
        let capture = FakeMirrorCapture()
        let camera = MirrorCameraController(capture: capture)
        camera.setActive(true)
        await assertEventually { await MainActor.run { camera.state == .running } }
        camera.setActive(true)
        camera.setActive(true)
        XCTAssertEqual(capture.startCount, 1)
    }

    // MARK: - Authorization

    func testDeniedAuthorizationNeverStartsCapture() async {
        let capture = FakeMirrorCapture()
        capture.authorizationToReturn = .denied
        let camera = MirrorCameraController(capture: capture)
        camera.setActive(true)
        await assertEventually { await MainActor.run { camera.state == .denied } }
        XCTAssertEqual(capture.startCount, 0)
    }

    func testRestrictedAuthorizationIsTreatedAsDenied() async {
        let capture = FakeMirrorCapture()
        capture.authorizationToReturn = .restricted
        let camera = MirrorCameraController(capture: capture)
        camera.setActive(true)
        await assertEventually { await MainActor.run { camera.state == .denied } }
        XCTAssertEqual(capture.startCount, 0)
    }

    func testUndeterminedAuthorizationStartsOnceGranted() async {
        let capture = FakeMirrorCapture()
        capture.authorizationToReturn = .notDetermined
        capture.accessGranted = true
        let camera = MirrorCameraController(capture: capture)
        camera.setActive(true)
        await assertEventually { await MainActor.run { camera.state == .running } }
        XCTAssertEqual(capture.authorizationRequestCount, 1)
    }

    func testUndeterminedAuthorizationRefusedEndsDenied() async {
        let capture = FakeMirrorCapture()
        capture.authorizationToReturn = .notDetermined
        capture.accessGranted = false
        let camera = MirrorCameraController(capture: capture)
        camera.setActive(true)
        await assertEventually { await MainActor.run { camera.state == .denied } }
        XCTAssertEqual(capture.startCount, 0)
    }

    // MARK: - Interruption and loss

    func testInterruptionPausesPreviewAndResumingRestoresIt() async {
        let capture = FakeMirrorCapture()
        let camera = MirrorCameraController(capture: capture)
        camera.setActive(true)
        await assertEventually { await MainActor.run { camera.state == .running } }
        capture.emit(.interrupted)
        await assertEventually { await MainActor.run { camera.state == .interrupted } }
        capture.emit(.interruptionEnded)
        await assertEventually { await MainActor.run { camera.state == .running } }
    }

    /// Resuming must actually restart the session, not just relabel the state, or the
    /// UI would claim `.running` over a frozen preview.
    func testResumingAfterInterruptionRestartsTheSession() async {
        let capture = FakeMirrorCapture()
        let camera = MirrorCameraController(capture: capture)
        camera.setActive(true)
        await assertEventually { await MainActor.run { camera.state == .running } }
        XCTAssertEqual(capture.startCount, 1)
        capture.emit(.interrupted)
        await assertEventually { await MainActor.run { camera.state == .interrupted } }
        capture.emit(.interruptionEnded)
        await assertEventually { await MainActor.run { camera.state == .running } }
        XCTAssertEqual(capture.startCount, 2, "Resuming must ask the capture layer to run again")
    }

    /// A device that disappeared while interrupted must surface as unavailable.
    func testResumingAfterInterruptionReportsUnavailableWhenDeviceIsGone() async {
        let capture = FakeMirrorCapture()
        let camera = MirrorCameraController(capture: capture)
        camera.setActive(true)
        await assertEventually { await MainActor.run { camera.state == .running } }
        capture.emit(.interrupted)
        await assertEventually { await MainActor.run { camera.state == .interrupted } }
        capture.startResult = .noDevice
        capture.emit(.interruptionEnded)
        await assertEventually { await MainActor.run { camera.state == .unavailable } }
    }

    /// Closing and reopening the mirror while the system prompt is still up must not
    /// strand the controller in `.requesting`.
    func testPermissionGrantArrivingAfterReopenStillStartsPreview() async {
        let capture = FakeMirrorCapture()
        capture.authorizationToReturn = .notDetermined
        capture.holdsAuthorization = true

        let camera = MirrorCameraController(capture: capture)
        camera.setActive(true)
        XCTAssertEqual(camera.state, .requesting)

        // The mirror is dismissed and reopened while the prompt is still up.
        camera.setActive(false)
        XCTAssertEqual(camera.state, .inactive)
        camera.setActive(true)
        XCTAssertEqual(camera.state, .requesting)
        XCTAssertEqual(capture.authorizationRequestCount, 1, "Only one system prompt may be raised")

        capture.authorizationToReturn = .authorized
        capture.finishPendingAuthorization(true)
        await assertEventually { await MainActor.run { camera.state == .running } }
    }

    func testInterruptionEndedWithoutInterruptionIsIgnored() async {
        let capture = FakeMirrorCapture()
        let camera = MirrorCameraController(capture: capture)
        camera.setActive(true)
        await assertEventually { await MainActor.run { camera.state == .running } }
        capture.emit(.interruptionEnded)
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(camera.state, .running)
    }

    func testRuntimeErrorStopsCaptureAndReportsUnavailable() async {
        let capture = FakeMirrorCapture()
        let camera = MirrorCameraController(capture: capture)
        camera.setActive(true)
        await assertEventually { await MainActor.run { camera.state == .running } }
        let stopsBefore = capture.stopCount
        capture.emit(.runtimeError)
        await assertEventually { await MainActor.run { camera.state == .unavailable } }
        XCTAssertGreaterThan(capture.stopCount, stopsBefore)
    }

    func testLosingTheDeviceStopsCaptureAndReportsUnavailable() async {
        let capture = FakeMirrorCapture()
        let camera = MirrorCameraController(capture: capture)
        camera.setActive(true)
        await assertEventually { await MainActor.run { camera.state == .running } }
        let stopsBefore = capture.stopCount
        capture.emit(.deviceLost)
        await assertEventually { await MainActor.run { camera.state == .unavailable } }
        XCTAssertGreaterThan(capture.stopCount, stopsBefore)
    }

    func testEventsArrivingAfterDeactivationAreIgnored() async {
        let capture = FakeMirrorCapture()
        let camera = MirrorCameraController(capture: capture)
        camera.setActive(true)
        await assertEventually { await MainActor.run { camera.state == .running } }
        camera.setActive(false)
        XCTAssertEqual(camera.state, .inactive)
        capture.emit(.interrupted)
        capture.emit(.runtimeError)
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(camera.state, .inactive)
    }

    // MARK: - Teardown ordering

    func testStartCompletionArrivingAfterDeactivationIsDiscarded() async {
        let capture = FakeMirrorCapture()
        capture.holdsStart = true
        let camera = MirrorCameraController(capture: capture)
        camera.setActive(true)
        XCTAssertEqual(camera.state, .starting)
        camera.setActive(false)
        XCTAssertEqual(camera.state, .inactive)
        capture.finishPendingStart(.running)
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(camera.state, .inactive, "A stale start must not revive a torn-down preview")
    }

    func testDeactivationStopsCapture() async {
        let capture = FakeMirrorCapture()
        let camera = MirrorCameraController(capture: capture)
        camera.setActive(true)
        await assertEventually { await MainActor.run { camera.state == .running } }
        camera.setActive(false)
        XCTAssertEqual(capture.stopCount, 1)
    }

    // MARK: - Retry

    func testRetryAfterUnavailableStartsAgain() async {
        let capture = FakeMirrorCapture()
        capture.startResult = .noDevice
        let camera = MirrorCameraController(capture: capture)
        camera.setActive(true)
        await assertEventually { await MainActor.run { camera.state == .unavailable } }
        capture.startResult = .running
        camera.retry()
        await assertEventually { await MainActor.run { camera.state == .running } }
        XCTAssertEqual(capture.startCount, 2)
    }

    func testRetryWhileInactiveDoesNothing() async {
        let capture = FakeMirrorCapture()
        let camera = MirrorCameraController(capture: capture)
        camera.retry()
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(camera.state, .inactive)
        XCTAssertEqual(capture.startCount, 0)
    }

    // MARK: - Mirrored preference

    func testMirroredPreferenceDefaultsOnAndPersists() throws {
        let store = try makeStore()
        XCTAssertTrue(store.isMirrorImageFlipped)
        let camera = MirrorCameraController(capture: FakeMirrorCapture(), settings: store)
        XCTAssertTrue(camera.isMirrored)
        camera.toggleMirrored()
        XCTAssertFalse(camera.isMirrored)
        XCTAssertFalse(store.isMirrorImageFlipped, "Flipping must be written through to settings")

        let reopened = MirrorCameraController(capture: FakeMirrorCapture(), settings: store)
        XCTAssertFalse(reopened.isMirrored, "A new controller must adopt the stored preference")
    }

    func testMirroredPreferenceWithoutStoreStaysInMemory() {
        let camera = MirrorCameraController(capture: FakeMirrorCapture())
        XCTAssertTrue(camera.isMirrored)
        camera.setMirrored(false)
        XCTAssertFalse(camera.isMirrored)
        camera.setMirrored(false)
        XCTAssertFalse(camera.isMirrored)
    }

    // MARK: - Settings store

    func testResetMirrorRestoresDefaults() throws {
        let store = try makeStore()
        store.isMirrorLiveActivityEnabled = false
        store.isMirrorImageFlipped = false
        store.resetMirror()
        XCTAssertTrue(store.isMirrorLiveActivityEnabled)
        XCTAssertTrue(store.isMirrorImageFlipped)
    }

    func testMirrorLiveActivityPreferenceIsReadThroughSettingsViewModel() throws {
        suiteName = "NotchFlow.MirrorPreference." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let settings = SettingsViewModel(defaults: defaults)
        XCTAssertTrue(settings.isLiveActivityEnabled(.mirror))
        settings.mediaAndFiles.isMirrorLiveActivityEnabled = false
        XCTAssertFalse(settings.isLiveActivityEnabled(.mirror))
        settings.reset(.mirror)
        XCTAssertTrue(settings.isLiveActivityEnabled(.mirror))
    }

    /// The default controller must never pick the real camera layer under tests.
    func testDefaultControllerUsesInactiveCaptureUnderTests() async {
        let camera = MirrorCameraController()
        camera.setActive(true)
        await assertEventually { await MainActor.run { camera.state == .unavailable } }
        camera.setActive(false)
        XCTAssertEqual(camera.state, .inactive)
    }
}
