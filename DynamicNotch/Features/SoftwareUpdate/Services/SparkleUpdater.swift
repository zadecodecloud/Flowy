// NotchFlow modification: updater intentionally disabled until a fork-owned signed feed exists.
import Foundation
import Combine
final class SparkleUpdater: ObservableObject {
    static let shared = SparkleUpdater()
    @Published var canCheckForUpdates = false
    @Published var automaticallyChecksForUpdates = false
    @Published var automaticallyDownloadsUpdates = false
    @Published var isUpdateAvailable = false
    @Published var latestVersionString = ""
    private init() {}
    func checkForUpdates() {}
    func startAutomaticCheckOnLaunch() {}
}
