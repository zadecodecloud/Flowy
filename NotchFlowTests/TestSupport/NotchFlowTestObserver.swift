import Foundation
import XCTest

/// The unit tests run inside the app (TEST_HOST), so `UserDefaults.standard` is the real
/// app's preferences domain. Many tests and app types write to it, which used to leave test
/// values behind (for example a test language that the app then started in).
///
/// This observer is the test bundle's principal class. Xcode runs the tests in several
/// processes at once, so they coordinate through a lock file: the first process to start
/// saves the domain, and the last one to finish puts it back. The saved copy is a file, so a
/// run that crashes before restoring is repaired when the next run starts.
@objc(NotchFlowTestObserver)
final class NotchFlowTestObserver: NSObject, XCTestObservation {
    static let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("NotchFlowTests-defaults", isDirectory: true)
    private static var backupURL: URL { directory.appendingPathComponent("backup.plist") }
    private static var processesURL: URL { directory.appendingPathComponent("processes", isDirectory: true) }

    private let domain = Bundle.main.bundleIdentifier ?? "app.notchflow.mac"
    private let pid = ProcessInfo.processInfo.processIdentifier

    override init() {
        super.init()
        XCTestObservationCenter.shared.addTestObserver(self)
    }

    func testBundleWillStart(_ testBundle: Bundle) {
        withLock {
            if liveProcesses().isEmpty {
                restoreBackup()   // left behind by a run that crashed
                saveBackup()
            }
            FileManager.default.createFile(atPath: marker(for: pid).path, contents: nil)
        }
    }

    func testBundleDidFinish(_ testBundle: Bundle) {
        withLock {
            try? FileManager.default.removeItem(at: marker(for: pid))
            if liveProcesses().isEmpty { restoreBackup() }
        }
    }

    // MARK: - Backup

    private func saveBackup() {
        let snapshot = UserDefaults.standard.persistentDomain(forName: domain) ?? [:]
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: snapshot, format: .binary, options: 0)
            try data.write(to: Self.backupURL, options: .atomic)
        } catch {
            NSLog("NotchFlowTests: could not save app defaults before testing: \(error)")
        }
    }

    private func restoreBackup() {
        guard let data = try? Data(contentsOf: Self.backupURL),
              let saved = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return }
        UserDefaults.standard.setPersistentDomain(saved, forName: domain)
        UserDefaults.standard.synchronize()
        try? FileManager.default.removeItem(at: Self.backupURL)
    }

    // MARK: - Process registry

    private func marker(for pid: Int32) -> URL {
        Self.processesURL.appendingPathComponent(String(pid))
    }

    /// Registered test processes that are still running; markers of dead ones are removed.
    private func liveProcesses() -> [Int32] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: Self.processesURL.path)) ?? []
        return names.compactMap { name -> Int32? in
            guard let other = Int32(name) else { return nil }
            if kill(other, 0) == 0 || errno == EPERM { return other }
            try? FileManager.default.removeItem(at: marker(for: other))
            return nil
        }
    }

    private func withLock(_ body: () -> Void) {
        try? FileManager.default.createDirectory(at: Self.processesURL, withIntermediateDirectories: true)
        let fd = open(Self.directory.appendingPathComponent("lock").path, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else { body(); return }
        flock(fd, LOCK_EX)
        body()
        flock(fd, LOCK_UN)
        close(fd)
    }
}
