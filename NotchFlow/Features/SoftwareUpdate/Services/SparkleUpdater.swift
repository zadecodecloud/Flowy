// NotchFlow modification: Sparkle 2 updater with a NotchFlow-owned EdDSA-signed feed.
// Disabled (canCheckForUpdates = false) until Info.plist has an https SUFeedURL and SUPublicEDKey.
import Foundation
import Combine
import Sparkle

final class SparkleUpdater: NSObject, ObservableObject {
    static let shared = SparkleUpdater()

    @Published var canCheckForUpdates = false
    @Published var automaticallyChecksForUpdates = false {
        didSet {
            guard let updater = controller?.updater,
                  updater.automaticallyChecksForUpdates != automaticallyChecksForUpdates else { return }
            updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        }
    }
    @Published var automaticallyDownloadsUpdates = false {
        didSet {
            guard let updater = controller?.updater,
                  updater.automaticallyDownloadsUpdates != automaticallyDownloadsUpdates else { return }
            updater.automaticallyDownloadsUpdates = automaticallyDownloadsUpdates
        }
    }
    @Published var isUpdateAvailable = false
    @Published var latestVersionString = ""

    private var controller: SPUStandardUpdaterController?
    private var cancellables: Set<AnyCancellable> = []

    /// True when this build has a signed update feed configured.
    static var isConfigured: Bool {
        let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? ""
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        return feed.hasPrefix("https://") && !key.isEmpty
    }

    private override init() {
        super.init()
        guard Self.isConfigured, !AppEnvironment.isRunningTests else { return }
        let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
        self.controller = controller
        let updater = controller.updater
        automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
        updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.canCheckForUpdates = $0 }
            .store(in: &cancellables)
    }

    /// Shows Sparkle's update window (user-initiated).
    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }

    /// Quiet check at launch so the notch and Settings can show an "update available" badge.
    func startAutomaticCheckOnLaunch() {
        guard let updater = controller?.updater, updater.automaticallyChecksForUpdates else { return }
        updater.checkForUpdateInformation()
    }
}

extension SparkleUpdater: SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        DispatchQueue.main.async {
            self.latestVersionString = item.displayVersionString
            self.isUpdateAvailable = true
        }
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        DispatchQueue.main.async { self.isUpdateAvailable = false }
    }
}
