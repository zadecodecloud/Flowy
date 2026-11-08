#if DEBUG
import SwiftUI
internal import AppKit

/// A test-only, ordinary window. It never locks the Mac or opens an overlay over the login screen.
@MainActor
final class LockScreenPreviewController {
    private let settings: SettingsViewModel
    private let nowPlaying: NowPlayingViewModel
    private let fixtureSnapshot: NowPlayingSnapshot
    private let lockManager = LockScreenManager(service: InactiveLockScreenMonitoringService())
    private let animator = LockScreenPanelAnimator()
    private var window: NSWindow?

    init() {
        let defaults = UserDefaults(suiteName: "local.NotchFlow.lockScreenPreview")!
        defaults.set(false, forKey: GeneralSettingsStorage.Keys.launchAtLogin)
        settings = SettingsViewModel(defaults: defaults)
        settings.lockScreen.isLockScreenLyricsEnabled = !ProcessInfo.processInfo.arguments.contains("-preview-no-lyrics")
        settings.lockScreen.isLockScreenArtworkExpanded = false
        settings.application.notchLanguage = .english
        let snapshot = NowPlayingSnapshot(title: "Blue Hour", artist: "NotchFlow Sessions", album: "Afterglow",
                                          duration: 240, elapsedTime: 24, playbackRate: 1,
                                          artworkData: Self.sampleArtwork(), volume: 0.55, supportsVolumeControl: true, refreshedAt: .now)
        fixtureSnapshot = snapshot
        nowPlaying = NowPlayingViewModel(service: PreviewNowPlayingService(snapshot: snapshot), lyricsProvider: PreviewLyricsProvider())
        nowPlaying.lyricsRetryDelays = []
        nowPlaying.startMonitoring()
        animator.isPresented = true
        animator.closeExpandedPlayer()
    }

    func show() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let snapshot = nowPlaying.snapshot ?? fixtureSnapshot
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1200, height: 760),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Lock Screen Preview"
        window.contentView = NSHostingView(rootView: ZStack {
            Image("backgroundDark")
                .resizable().scaledToFill()
                .frame(width: 1200, height: 760).clipped()
            LockScreenMediaBackgroundView(artworkImage: nowPlaying.artworkImage, settingsViewModel: settings,
                                          nowPlayingViewModel: nowPlaying, animator: animator)
            LockScreenNowPlayingPanelView(snapshot: snapshot, artworkImage: nowPlaying.artworkImage,
                                          screen: screen, settingsViewModel: settings,
                                          nowPlayingViewModel: nowPlaying, lockScreenManager: lockManager,
                                          animator: animator)
        })
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    private static func sampleArtwork() -> Data? {
        // Distinct light and dark regions exercise the album-derived backdrop.
        let square = NSRect(x: 0, y: 0, width: 560, height: 560)
        let image = NSImage(size: square.size, flipped: false) { _ in
            NSGradient(colors: [NSColor(srgbRed: 0.04, green: 0.10, blue: 0.23, alpha: 1),
                                NSColor(srgbRed: 0.37, green: 0.51, blue: 0.68, alpha: 1)])?.draw(in: square, angle: 36)
            NSColor(srgbRed: 0.97, green: 0.77, blue: 0.56, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: 230, y: 168, width: 215, height: 215)).fill()
            let ridge = NSBezierPath()
            ridge.move(to: .zero)
            ridge.line(to: NSPoint(x: 0, y: 125))
            ridge.curve(to: NSPoint(x: 560, y: 260), controlPoint1: NSPoint(x: 180, y: 180),
                        controlPoint2: NSPoint(x: 365, y: 90))
            ridge.line(to: NSPoint(x: 560, y: 0))
            ridge.close()
            NSColor(srgbRed: 0.09, green: 0.19, blue: 0.27, alpha: 1).setFill()
            ridge.fill()
            ("BLUE HOUR" as NSString).draw(at: NSPoint(x: 37, y: 452), withAttributes: [
                .font: NSFont.systemFont(ofSize: 46, weight: .medium), .kern: 2,
                .foregroundColor: NSColor.white.withAlphaComponent(0.89)])
            return true
        }
        guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}

private final class PreviewNowPlayingService: NowPlayingMonitoring {
    var onSnapshotChange: ((NowPlayingSnapshot?) -> Void)?
    private var snapshot: NowPlayingSnapshot
    init(snapshot: NowPlayingSnapshot) { self.snapshot = snapshot }
    func startMonitoring() { onSnapshotChange?(snapshot) }
    func stopMonitoring() {}
    func send(_ command: NowPlayingCommand) {
        switch command {
        case .play: snapshot = snapshot.settingPlaybackRate(1)
        case .pause: snapshot = snapshot.settingPlaybackRate(0)
        case .togglePlayPause: snapshot = snapshot.togglingPlaybackState()
        case .seek(let time): snapshot = snapshot.settingElapsedTime(time)
        case .setShuffle(let enabled): snapshot = snapshot.settingShuffle(enabled)
        case .setRepeatMode(let mode): snapshot = snapshot.settingRepeatMode(mode)
        case .setVolume(let volume): snapshot = snapshot.settingVolume(volume)
        case .nextTrack, .previousTrack:
            snapshot = NowPlayingSnapshot(title: command == .nextTrack ? "Afterglow" : "Blue Hour",
                artist: "NotchFlow Sessions", album: "Afterglow", duration: 240, elapsedTime: 24,
                playbackRate: 1, artworkData: snapshot.artworkData,
                isShuffled: snapshot.isShuffled, repeatMode: snapshot.repeatMode,
                volume: snapshot.volume, supportsVolumeControl: true, refreshedAt: .now)
        default: break
        }
        onSnapshotChange?(snapshot)
    }
}

@MainActor
private final class PreviewLyricsProvider: LyricsProviding {
    func lyrics(for snapshot: NowPlayingSnapshot) async throws -> TrackLyrics? {
        guard let key = snapshot.lyricsLookupKey else { return nil }
        if ProcessInfo.processInfo.arguments.contains("-preview-missing-lyrics") { return nil }
        if ProcessInfo.processInfo.arguments.contains("-preview-failed-lyrics") { throw URLError(.notConnectedToInternet) }
        let isPlain = ProcessInfo.processInfo.arguments.contains("-preview-plain-lyrics")
        let cues = LRCLIBLyricsProvider.parseSyncedLyrics("""
        [00:01.00]Bóng chiều nằm nghiêng bên cửa sổ
        [00:10.00]Một vệt nắng trôi qua thềm
        [00:20.00]<00:20.00>Phố <00:21.00>lên <00:22.00>đèn <00:24.00>khi <00:25.00>trời <00:27.00>vừa <00:28.00>xanh<00:29.50>
        [00:30.00]Và con đường sáng lên dưới chân
        [00:40.00]
        [00:46.00]Có tiếng cười ở phía bên kia
        [00:55.00]Ta đi chậm thêm một chút
        [01:03.00]Cho đêm vừa kịp ghé qua
        [01:14.00]Một ô cửa vẫn còn sáng
        [01:25.00]Gió đưa tiếng đàn về nhà
        """)
        return TrackLyrics(trackKey: key, lines: cues, isSynced: !isPlain)
    }
}
#endif
