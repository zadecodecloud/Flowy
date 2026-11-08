import SwiftUI
import Combine
@preconcurrency import AVFoundation
internal import AppKit

@MainActor
final class MirrorCameraController: ObservableObject {
    enum State: Equatable {
        case inactive
        case requesting
        case starting
        case running
        /// Session configured but suspended — another app took the camera, or the system paused it.
        case interrupted
        case denied
        case unavailable
    }

    @Published private(set) var state: State = .inactive

    /// Mirrored (selfie-style) preview. Persisted when a settings store is attached.
    @Published private(set) var isMirrored: Bool

    private let capture: MirrorCaptureControlling
    private let settings: MediaAndFilesSettingsStore?
    private var wantsPreview = false
    private var permissionPending = false
    /// Invalidates in-flight start/permission callbacks after the preview is torn down.
    private var generation = 0
    let previewLayer = AVCaptureVideoPreviewLayer()

    /// `capture` defaults to the real camera, or to an inactive stand-in under tests so
    /// no test run can reach the camera or raise a TCC prompt.
    init(capture: MirrorCaptureControlling? = nil, settings: MediaAndFilesSettingsStore? = nil) {
        let resolved = capture ?? (AppEnvironment.isRunningTests
            ? InactiveMirrorCapture() as MirrorCaptureControlling
            : MirrorCaptureWorker())
        self.capture = resolved
        self.settings = settings
        self.isMirrored = settings?.isMirrorImageFlipped ?? true
        previewLayer.session = resolved.previewSession
        previewLayer.videoGravity = .resizeAspectFill
        resolved.observeEvents { [weak self] event in
            Task { @MainActor [weak self] in self?.handle(event) }
        }
    }

    /// Call only for a visible, expanded mirror. It never records or saves video.
    func setActive(_ active: Bool) {
        guard active != wantsPreview else { return }
        wantsPreview = active
        generation += 1
        if !active {
            capture.stop()
            state = .inactive
            return
        }
        resolveAccess(generation: generation)
    }

    /// Retries whichever step failed: authorization, or starting the session.
    func retry() {
        guard wantsPreview else { return }
        generation += 1
        resolveAccess(generation: generation)
    }

    func setMirrored(_ mirrored: Bool) {
        guard mirrored != isMirrored else { return }
        isMirrored = mirrored
        settings?.isMirrorImageFlipped = mirrored
        applyMirroring()
    }

    func toggleMirrored() {
        setMirrored(!isMirrored)
    }

    func applyMirroring() {
        guard let connection = previewLayer.connection, connection.isVideoMirroringSupported else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = isMirrored
    }

    func openCameraSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") else { return }
        NSWorkspace.shared.open(url)
    }

    private func resolveAccess(generation: Int) {
        switch capture.authorization {
        case .authorized:
            startSession(generation: generation)
        case .notDetermined:
            state = .requesting
            guard !permissionPending else { return }
            permissionPending = true
            // The grant is global, not tied to this activation, so it is applied with
            // whatever generation is current when it lands. Dropping it on a stale
            // generation would leave a reopened mirror stuck in `.requesting`.
            capture.requestAuthorization { [weak self] granted in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.permissionPending = false
                    guard self.wantsPreview else { return }
                    if granted { self.startSession(generation: self.generation) } else { self.state = .denied }
                }
            }
        case .denied, .restricted:
            state = .denied
        @unknown default:
            state = .unavailable
        }
    }

    private func startSession(generation: Int) {
        state = .starting
        capture.start { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self, self.wantsPreview, self.generation == generation else { return }
                switch result {
                case .running:
                    self.state = .running
                    self.applyMirroring()
                case .noDevice, .failed:
                    self.state = .unavailable
                }
            }
        }
    }

    private func handle(_ event: MirrorCaptureEvent) {
        guard wantsPreview else { return }
        switch event {
        case .interrupted:
            if state == .running { state = .interrupted }
        case .interruptionEnded:
            // A session is not guaranteed to resume on its own, so start it again
            // rather than claiming `.running` over a frozen preview.
            if state == .interrupted {
                generation += 1
                startSession(generation: generation)
            }
        case .runtimeError, .deviceLost:
            capture.stop()
            state = .unavailable
        }
    }

    deinit { capture.stop() }
}

struct MirrorCameraPreview: NSViewRepresentable {
    @ObservedObject var camera: MirrorCameraController
    func makeNSView(context: Context) -> MirrorPreviewContainer {
        MirrorPreviewContainer(previewLayer: camera.previewLayer)
    }
    func updateNSView(_ view: MirrorPreviewContainer, context: Context) {
        camera.applyMirroring()
    }
}

final class MirrorPreviewContainer: NSView {
    private weak var previewLayer: AVCaptureVideoPreviewLayer?
    init(previewLayer: AVCaptureVideoPreviewLayer) {
        self.previewLayer = previewLayer
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.masksToBounds = true
        layer?.addSublayer(previewLayer)
    }
    required init?(coder: NSCoder) { nil }
    override func layout() {
        super.layout()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        previewLayer?.frame = bounds
        CATransaction.commit()
    }
}
