import Foundation
@preconcurrency import AVFoundation

/// Outcome of a capture start attempt.
enum MirrorCaptureStartResult: Equatable, Sendable {
    case running
    /// No usable video device is attached.
    case noDevice
    /// A device exists but the session refused to configure or run.
    case failed
}

/// Conditions the capture layer reports once a session has been configured.
enum MirrorCaptureEvent: Equatable, Sendable {
    /// Another client took the camera, or the system suspended the session.
    case interrupted
    case interruptionEnded
    case runtimeError
    /// The device backing the running session went away.
    case deviceLost
}

/// Capture layer behind the mirror preview.
///
/// Every member is `nonisolated`: the real implementation owns a serial queue and
/// never touches the main thread, so callbacks arrive on an arbitrary thread and
/// callers hop to the main actor themselves.
protocol MirrorCaptureControlling: AnyObject, Sendable {
    nonisolated var previewSession: AVCaptureSession? { get }
    nonisolated var authorization: AVAuthorizationStatus { get }
    nonisolated func requestAuthorization(completion: @escaping @Sendable (Bool) -> Void)
    nonisolated func observeEvents(_ handler: @escaping @Sendable (MirrorCaptureEvent) -> Void)
    nonisolated func start(completion: @escaping @Sendable (MirrorCaptureStartResult) -> Void)
    nonisolated func stop()
}

/// Stand-in for tests and previews. It never reaches the camera or TCC, so it can
/// never raise a permission prompt; `start` always reports that no device exists.
nonisolated final class InactiveMirrorCapture: MirrorCaptureControlling, @unchecked Sendable {
    var previewSession: AVCaptureSession? { nil }
    var authorization: AVAuthorizationStatus { .authorized }
    func requestAuthorization(completion: @escaping @Sendable (Bool) -> Void) { completion(false) }
    func observeEvents(_ handler: @escaping @Sendable (MirrorCaptureEvent) -> Void) {}
    func start(completion: @escaping @Sendable (MirrorCaptureStartResult) -> Void) { completion(.noDevice) }
    func stop() {}
}

/// Real capture layer. The session, its input and all mutable state are confined to
/// `queue`; the preview layer reads the session reference, which is immutable.
nonisolated final class MirrorCaptureWorker: MirrorCaptureControlling, @unchecked Sendable {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "app.notchflow.mac.mirror.capture", qos: .userInitiated)

    // Touched on `queue` only.
    private var configured = false
    private var activeDeviceID: String?
    private var observers: [NSObjectProtocol] = []
    private var eventHandler: (@Sendable (MirrorCaptureEvent) -> Void)?

    var previewSession: AVCaptureSession? { session }
    var authorization: AVAuthorizationStatus { AVCaptureDevice.authorizationStatus(for: .video) }

    func requestAuthorization(completion: @escaping @Sendable (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video, completionHandler: completion)
    }

    func observeEvents(_ handler: @escaping @Sendable (MirrorCaptureEvent) -> Void) {
        queue.async {
            self.eventHandler = handler
            self.registerObserversOnQueue()
        }
    }

    func start(completion: @escaping @Sendable (MirrorCaptureStartResult) -> Void) {
        queue.async {
            if !self.configured {
                guard let device = AVCaptureDevice.default(for: .video) else {
                    completion(.noDevice); return
                }
                guard let input = try? AVCaptureDeviceInput(device: device) else {
                    completion(.failed); return
                }
                self.session.beginConfiguration()
                self.session.sessionPreset = .high
                guard self.session.canAddInput(input) else {
                    self.session.commitConfiguration(); completion(.failed); return
                }
                self.session.addInput(input)
                self.session.commitConfiguration()
                self.configured = true
                self.activeDeviceID = device.uniqueID
            }
            if !self.session.isRunning { self.session.startRunning() }
            completion(self.session.isRunning ? .running : .failed)
        }
    }

    func stop() {
        queue.async { if self.session.isRunning { self.session.stopRunning() } }
    }

    /// Dropping the inputs lets a later `start` pick up whatever device is attached then.
    private func discardConfigurationOnQueue() {
        if session.isRunning { session.stopRunning() }
        session.beginConfiguration()
        for input in session.inputs { session.removeInput(input) }
        session.commitConfiguration()
        configured = false
        activeDeviceID = nil
    }

    private func registerObserversOnQueue() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default

        observers.append(center.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            self.queue.async {
                self.discardConfigurationOnQueue()
                self.eventHandler?(.runtimeError)
            }
        })

        observers.append(center.addObserver(
            forName: AVCaptureSession.wasInterruptedNotification, object: session, queue: nil
        ) { [weak self] _ in
            self?.queue.async { self?.eventHandler?(.interrupted) }
        })

        observers.append(center.addObserver(
            forName: AVCaptureSession.interruptionEndedNotification, object: session, queue: nil
        ) { [weak self] _ in
            self?.queue.async { self?.eventHandler?(.interruptionEnded) }
        })

        // Posted for every device, so compare against the one actually in use.
        observers.append(center.addObserver(
            forName: AVCaptureDevice.wasDisconnectedNotification, object: nil, queue: nil
        ) { [weak self] notification in
            guard let self, let lost = (notification.object as? AVCaptureDevice)?.uniqueID else { return }
            self.queue.async {
                guard self.activeDeviceID == lost else { return }
                self.discardConfigurationOnQueue()
                self.eventHandler?(.deviceLost)
            }
        })
    }

    deinit {
        if session.isRunning { session.stopRunning() }
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
    }
}
