import Foundation
import CoreGraphics

final class DistributedLockScreenMonitoringService: LockScreenMonitoring {
    var onLockStateChange: ((Bool) -> Void)?

    private let center: DistributedNotificationCenter
    private let queryLockState: () -> Bool?
    private let reconciliationInterval: TimeInterval
    private var observers: [NSObjectProtocol] = []
    private var timer: Timer?
    private var isMonitoring = false
    private var lastPublishedState: Bool?

    init(center: DistributedNotificationCenter = .default(),
         reconciliationInterval: TimeInterval = 2,
         queryLockState: @escaping () -> Bool? = {
             guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return nil }
             return session["CGSSessionScreenIsLocked"] as? Bool ?? false
         }) {
        self.center = center
        self.reconciliationInterval = reconciliationInterval
        self.queryLockState = queryLockState
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        lastPublishedState = nil
        observers = [
            center.addObserver(forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
                self?.publish(true)
            },
            center.addObserver(forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
                self?.publish(false)
            }
        ]
        reconcileState()
        // Reconcile missed notifications, including launch while already locked and wake.
        timer = Timer.scheduledTimer(withTimeInterval: reconciliationInterval, repeats: true) { [weak self] _ in
            self?.reconcileState()
        }
        timer?.tolerance = min(0.5, reconciliationInterval / 4)
    }

    func reconcileState() {
        guard isMonitoring, let locked = queryLockState() else { return }
        publish(locked)
    }

    private func publish(_ locked: Bool) {
        guard isMonitoring, lastPublishedState != locked else { return }
        lastPublishedState = locked
        onLockStateChange?(locked)
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        timer?.invalidate()
        timer = nil
        observers.forEach(center.removeObserver)
        observers.removeAll()
    }

    deinit { stopMonitoring() }
}
