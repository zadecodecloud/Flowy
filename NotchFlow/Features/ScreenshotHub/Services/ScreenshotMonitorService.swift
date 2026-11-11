internal import AppKit
import Foundation
import Combine
import AVFoundation

final class ScreenshotMonitorService {
    var onScreenshotCaptured: ((NSImage, URL?, String) -> Void)?
    var onScreenRecordingCaptured: ((URL, NSImage, String) -> Void)?
    
    private(set) var userTargetDirectoryURL: URL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory())
    
    private var originalScreenshotLocation: String?
    /// Off: new screenshots are only moved to the user's folder, with no notch preview.
    var showsScreenshots = true
    private var fileWatcherTimer: Timer?
    private var knownFilePaths = Set<String>()
    private var isMonitoring = false
    private let fileManager = FileManager.default
    
    init() {}
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring(disableSystemThumbnail: Bool = true) {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        self.originalScreenshotLocation = Self.getSystemScreenshotLocation()
        self.userTargetDirectoryURL = computeUserTargetDirectoryURL()
        
        let stagingDir = rawStagingDirectoryURL()
        try? fileManager.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        
        // NotchFlow: never redirect the system screenshot location.
        rescueStagedFiles()
        
        if disableSystemThumbnail {
            // NotchFlow: leave the system thumbnail preference unchanged.
        }
        
        primeBaseline()
        
        fileWatcherTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.scanForNewScreenshots()
            self?.scanTargetDirectoryForRecordings()
        }
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        fileWatcherTimer?.invalidate()
        fileWatcherTimer = nil
        
        // No global screenshot preference was changed.
    }
    
    func updateLastPasteboardChangeCount() {}
    
    func suppressMonitoring(for duration: TimeInterval = 3.0) {}
    
    func rawStagingDirectoryURL() -> URL {
        Self.stagingDirectory(systemLocation: originalScreenshotLocation ?? Self.getSystemScreenshotLocation(),
                              ownDefault: ownStagingDirectoryURL())
    }

    private func ownStagingDirectoryURL() -> URL {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        return caches.appendingPathComponent("app.notchflow.mac/RawScreenshots")
    }

    /// macOS saves into a staging folder left by an earlier build: someone must empty it.
    var usesLeftoverStaging: Bool { rawStagingDirectoryURL() != ownStagingDirectoryURL() }

    /// Where new screenshots appear. macOS may still save into a `RawScreenshots` staging
    /// folder set by an earlier build or by DynamicNotch; read from there, or screenshots
    /// would sit unseen in a hidden folder. Any other location is the user's own: keep ours.
    static func stagingDirectory(systemLocation: String?, ownDefault: URL) -> URL {
        guard let systemLocation, !systemLocation.isEmpty else { return ownDefault }
        let expanded = (systemLocation as NSString).expandingTildeInPath
        guard URL(fileURLWithPath: expanded).lastPathComponent == "RawScreenshots" else { return ownDefault }
        return URL(fileURLWithPath: expanded)
    }

    /// Moves screenshots and recordings left in the staging folder (taken while NotchFlow was
    /// not running) to the user's folder, so none stay hidden.
    private func rescueStagedFiles() {
        let staging = rawStagingDirectoryURL()
        guard staging != userTargetDirectoryURL,
              let urls = try? fileManager.contentsOfDirectory(at: staging, includingPropertiesForKeys: [.isRegularFileKey],
                                                             options: [.skipsHiddenFiles]) else { return }
        for url in urls where (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true {
            let destination = uniqueURL(for: userTargetDirectoryURL.appendingPathComponent(url.lastPathComponent))
            try? fileManager.moveItem(at: url, to: destination)
        }
    }
    
    private func computeUserTargetDirectoryURL() -> URL {
        if let customPath = UserDefaults.standard.string(forKey: "settings.screenshot.savePath"), !customPath.isEmpty {
            let expanded = (customPath as NSString).expandingTildeInPath
            return URL(fileURLWithPath: expanded)
        }
        let desktop = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory())
        guard let original = originalScreenshotLocation, !original.isEmpty else {
            return desktop
        }
        let expanded = (original as NSString).expandingTildeInPath
        if expanded.contains("RawScreenshots") {
            return desktop
        }
        return URL(fileURLWithPath: expanded)
    }
    
    private func computeScreenRecordingTargetDirectoryURL() -> URL {
        if let customPath = UserDefaults.standard.string(forKey: "settings.screenRecording.savePath"), !customPath.isEmpty {
            let expanded = (customPath as NSString).expandingTildeInPath
            return URL(fileURLWithPath: expanded)
        }
        return computeUserTargetDirectoryURL()
    }
    
    private func uniqueURL(for targetURL: URL) -> URL {
        guard fileManager.fileExists(atPath: targetURL.path) else { return targetURL }
        
        let dir = targetURL.deletingLastPathComponent()
        let ext = targetURL.pathExtension
        let baseName = targetURL.deletingPathExtension().lastPathComponent
        
        var counter = 1
        var candidateURL = targetURL
        while fileManager.fileExists(atPath: candidateURL.path) {
            let newName = ext.isEmpty ? "\(baseName) (\(counter))" : "\(baseName) (\(counter)).\(ext)"
            candidateURL = dir.appendingPathComponent(newName)
            counter += 1
        }
        return candidateURL
    }
    
    private func primeBaseline() {
        let dir = rawStagingDirectoryURL()
        if let urls = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) {
            for url in urls {
                knownFilePaths.insert(url.path)
            }
        }

        let targetDir = computeScreenRecordingTargetDirectoryURL()
        if let urls = try? fileManager.contentsOfDirectory(at: targetDir, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) {
            for url in urls {
                knownFilePaths.insert(url.path)
            }
        }
    }
    
    func scanNow() {
        scanForNewScreenshots()
        scanTargetDirectoryForRecordings()
    }

    private func scanForNewScreenshots() {
        let dir = rawStagingDirectoryURL()
        guard let urls = try? fileManager.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        
        let now = Date()
        for url in urls {
            let path = url.path
            guard !knownFilePaths.contains(path) else { continue }
            
            let filename = url.lastPathComponent
            let lower = filename.lowercased()
            
            if lower.hasSuffix(".mov") || lower.hasSuffix(".mp4") || lower.contains("screen recording") || lower.contains("запись экрана") {
                guard let resourceValues = try? url.resourceValues(forKeys: [.isRegularFileKey]),
                      resourceValues.isRegularFile == true else { continue }
                
                let targetDir = computeScreenRecordingTargetDirectoryURL()
                try? fileManager.createDirectory(at: targetDir, withIntermediateDirectories: true)
                let destinationURL = uniqueURL(for: targetDir.appendingPathComponent(filename))
                do {
                    try fileManager.moveItem(at: url, to: destinationURL)
                    knownFilePaths.insert(path)
                    knownFilePaths.insert(destinationURL.path)

                    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                        let thumbnail = Self.generateVideoThumbnail(for: destinationURL) ?? NSWorkspace.shared.icon(forFile: destinationURL.path)
                        DispatchQueue.main.async {
                            self?.onScreenRecordingCaptured?(destinationURL, thumbnail, filename)
                        }
                    }
                } catch {
                    // File might be currently open/being written by screencapture, try again on next timer tick
                }
                continue
            }
            
            guard let resourceValues = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                  resourceValues.isRegularFile == true,
                  let modDate = resourceValues.contentModificationDate,
                  now.timeIntervalSince(modDate) < 10.0 else {
                knownFilePaths.insert(path)
                continue
            }
            
            if lower.contains("screenshot") || lower.contains("скриншот") || lower.hasSuffix(".png") || lower.hasSuffix(".jpg") {
                guard showsScreenshots else {
                    let destination = uniqueURL(for: userTargetDirectoryURL.appendingPathComponent(filename))
                    if (try? fileManager.moveItem(at: url, to: destination)) != nil {
                        knownFilePaths.insert(path)
                        knownFilePaths.insert(destination.path)
                    }
                    continue
                }
                if let image = NSImage(contentsOf: url) {
                    knownFilePaths.insert(path)
                    DispatchQueue.main.async { [weak self] in
                        self?.onScreenshotCaptured?(image, url, filename)
                    }
                    break
                }
            }
        }
    }

    private func scanTargetDirectoryForRecordings() {
        let targetDir = computeScreenRecordingTargetDirectoryURL()
        guard targetDir != rawStagingDirectoryURL() else { return }
        guard let urls = try? fileManager.contentsOfDirectory(
            at: targetDir,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let now = Date()
        for url in urls {
            let path = url.path
            guard !knownFilePaths.contains(path) else { continue }

            let filename = url.lastPathComponent
            let lower = filename.lowercased()
            guard lower.hasSuffix(".mov") || lower.hasSuffix(".mp4") || lower.contains("screen recording") || lower.contains("запись экрана") else {
                continue
            }

            guard let resourceValues = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                  resourceValues.isRegularFile == true,
                  let modDate = resourceValues.contentModificationDate,
                  now.timeIntervalSince(modDate) < 15.0 else {
                knownFilePaths.insert(path)
                continue
            }

            // Ensure the file is not currently locked/open for exclusive writing
            guard let fileHandle = try? FileHandle(forReadingFrom: url) else {
                continue
            }
            try? fileHandle.close()

            knownFilePaths.insert(path)

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let thumbnail = Self.generateVideoThumbnail(for: url) ?? NSWorkspace.shared.icon(forFile: url.path)
                DispatchQueue.main.async {
                    self?.onScreenRecordingCaptured?(url, thumbnail, filename)
                }
            }
        }
    }

    static func generateVideoThumbnail(for url: URL) -> NSImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 800, height: 800)

        let times = [
            CMTime(seconds: 0.5, preferredTimescale: 600),
            CMTime.zero,
            CMTime(seconds: 0.1, preferredTimescale: 600)
        ]

        for time in times {
            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            }
        }

        return nil
    }
    
    func markPathAsKnown(_ path: String) {
        knownFilePaths.insert(path)
    }
    
    /// Configures system preference to hide or show the default floating screenshot thumbnail in the bottom-right corner of macOS.
    static func setSystemFloatingThumbnailEnabled(_ enabled: Bool) {
        // NotchFlow does not mutate the system preference.
    }

    static func getSystemScreenshotLocation() -> String? {
        let key = "location" as CFString
        let domain = "com.apple.screencapture" as CFString
        return CFPreferencesCopyAppValue(key, domain) as? String
    }
    
    static func setSystemScreenshotLocation(_ path: String?) {
        // NotchFlow does not mutate the system preference.
    }
}
