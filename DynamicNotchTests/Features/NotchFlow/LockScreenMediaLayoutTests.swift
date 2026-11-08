import XCTest
import AppKit
import SwiftUI
@testable import DynamicNotch

final class LockScreenMediaLayoutTests: XCTestCase {
    @MainActor
    func testNonanimatedWindowRefreshDoesNotDisableUserTransitions() async throws {
        let animator = LockScreenPanelAnimator()
        animator.presentImmediately()
        XCTAssertTrue(animator.isPresented)
        XCTAssertFalse(animator.disablesTransitionAnimation)
        var preparedBeforeModeChange = false
        animator.prepareExpandedCanvas = { preparedBeforeModeChange = animator.mode == .compact }
        animator.expandArtwork()
        XCTAssertTrue(preparedBeforeModeChange)
        animator.presentImmediately()
        XCTAssertFalse(animator.disablesTransitionAnimation)
        animator.toggleLyrics()
        animator.closeExpandedPlayer()
        XCTAssertEqual(animator.mode, .compact)
        if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            XCTAssertTrue(animator.retainsExpandedCanvas, "Do not clip the cover during its return flight")
        }
        try await Task.sleep(for: .milliseconds(650))
        XCTAssertFalse(animator.retainsExpandedCanvas)
        animator.prepareExpandedCanvas = nil
    }

    @MainActor
    func testAmbientClockKeepsTickingUntilPresentationStops() async throws {
        let clock = LockScreenAmbientClock()
        clock.setActive(true)
        try await Task.sleep(for: .milliseconds(180))
        XCTAssertGreaterThan(clock.elapsed, 0.05)
        let before = clock.elapsed
        clock.setActive(true) // Playback updates must not reset the phase.
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertGreaterThan(clock.elapsed, before)
        clock.setActive(false)
        let stopped = clock.elapsed
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(clock.elapsed, stopped)
        clock.setActive(true)
        XCTAssertEqual(clock.elapsed, stopped, "Resume must not jump across the paused interval")
        clock.setActive(false)
    }

    func testAmbientFieldsChangeOverTimeWithoutSharpMeshBoundaries() {
        let start = LockScreenAmbientMesh.fields(at: 0)
        let later = LockScreenAmbientMesh.fields(at: 2)
        XCTAssertEqual(start.count, 7)
        XCTAssertNotEqual(start, later)
        for time in stride(from: 0.0, through: 120.0, by: 0.5) {
            for field in LockScreenAmbientMesh.fields(at: time) {
                XCTAssertTrue((0...1).contains(field.center.x))
                XCTAssertTrue((0...1).contains(field.center.y))
                XCTAssertTrue((0.39...0.65).contains(field.radius))
            }
        }
    }

    @MainActor
    func testDarkAlbumProducesBrighterButStillColoredBackground() throws {
        let image = NSImage(size: NSSize(width: 30, height: 30))
        image.lockFocus()
        NSColor(srgbRed: 0.24, green: 0.10, blue: 0.08, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: 30, height: 30).fill()
        image.unlockFocus()
        let color = try XCTUnwrap(NSColor(LockScreenAmbientMesh.colors(from: image)[4]).usingColorSpace(.deviceRGB))
        XCTAssertGreaterThan(color.redComponent, 0.24)
        XCTAssertGreaterThan(color.redComponent, color.greenComponent)
        XCTAssertLessThan(color.redComponent, 0.96)
    }

    @MainActor
    func testWideLyricsNavigationAndDisablingLyrics() {
        let animator = LockScreenPanelAnimator()
        animator.toggleLyricsSize()
        XCTAssertEqual(animator.mode, .compact)
        animator.expandArtwork()
        animator.toggleLyrics()
        animator.toggleLyricsSize()
        XCTAssertEqual(animator.mode, .lyricsWide)
        XCTAssertTrue(animator.showsLyrics)
        animator.toggleLyricsSize()
        XCTAssertEqual(animator.mode, .lyrics)
        animator.toggleLyricsSize()
        animator.toggleLyrics()
        XCTAssertEqual(animator.mode, .artwork)
        animator.toggleLyrics()
        animator.toggleLyricsSize()
        animator.disableLyrics()
        XCTAssertEqual(animator.mode, .artwork)
        XCTAssertFalse(animator.showsLyrics)
    }

    func testReferenceLyricsLayoutFitsAndMaintainsMeasuredProportions() {
        for size in [CGSize(width: 1200, height: 750), CGSize(width: 1512, height: 982),
                     CGSize(width: 735, height: 490), CGSize(width: 390, height: 844)] {
            let layout = LockScreenMediaLayout(screenSize: size, showsLyrics: true, wideLyrics: true)
            func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
                CGRect(x: size.width / 2 + x - w / 2, y: size.height / 2 + y - h / 2, width: w, height: h)
            }
            let art = rect(layout.artworkX, layout.artworkY, layout.artworkSize, layout.artworkSize)
            let player = rect(layout.playerX, layout.playerY, layout.playerWidth, layout.playerHeight)
            let lyrics = rect(layout.lyricsX, layout.lyricsY, layout.lyricsWidth, layout.lyricsHeight)
            let bounds = CGRect(origin: .zero, size: size)
            for region in [art, player, lyrics] { XCTAssertTrue(bounds.contains(region)) }
            XCTAssertFalse(art.intersects(player))
            XCTAssertFalse(art.intersects(lyrics))
            XCTAssertFalse(player.intersects(lyrics))
        }
        let reference = LockScreenMediaLayout(screenSize: CGSize(width: 1200, height: 750), showsLyrics: true, wideLyrics: true)
        XCTAssertEqual(reference.artworkSize, 348, accuracy: 1)
        XCTAssertEqual(reference.lyricsFontSize, 32, accuracy: 1)
        XCTAssertEqual(reference.playerHeight, 104)
    }

    @MainActor
    func testReopeningCancelsPendingCanvasCollapse() async throws {
        let animator = LockScreenPanelAnimator()
        animator.isPresented = true
        animator.expandArtwork()
        animator.closeExpandedPlayer()
        animator.toggleLyrics()
        try await Task.sleep(for: .milliseconds(650))
        XCTAssertEqual(animator.mode, .lyrics)
        XCTAssertFalse(animator.retainsExpandedCanvas)
        animator.disablesTransitionAnimation = true
        animator.closeExpandedPlayer()
        XCTAssertEqual(animator.mode, .compact)
        XCTAssertFalse(animator.retainsExpandedCanvas)
    }

    @MainActor
    func testBackgroundWindowPassesMouseEventsAndCannotBecomeKey() {
        let window = OverlayPanelFactory.makeLockScreenBackground(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertTrue(window.canBecomeVisibleWithoutLogin)
        XCTAssertTrue(window.ignoresMouseEvents)
        XCTAssertFalse(window.canBecomeKey)
        XCTAssertFalse(window.canBecomeMain)
    }

    func testExpandedPlayerAndLyricsFitAcrossScreenSizes() {
        for size in [CGSize(width: 1024, height: 768), CGSize(width: 1512, height: 982), CGSize(width: 1920, height: 1080)] {
            let layout = LockScreenMediaLayout(screenSize: size, showsLyrics: true)
            let artLeft = size.width / 2 + layout.artworkX - layout.artworkSize / 2
            let artRight = size.width / 2 + layout.artworkX + layout.artworkSize / 2
            let lyricsLeft = size.width / 2 + layout.lyricsX - layout.lyricsWidth / 2
            let lyricsRight = size.width / 2 + layout.lyricsX + layout.lyricsWidth / 2
            let artworkBottom = size.height / 2 + layout.artworkY + layout.artworkSize / 2
            let playerTop = size.height / 2 + layout.playerY - layout.playerHeight / 2
            let playerBottom = size.height / 2 + layout.playerY + layout.playerHeight / 2
            XCTAssertGreaterThanOrEqual(artLeft, 0)
            XCTAssertLessThanOrEqual(lyricsRight, size.width)
            XCTAssertGreaterThanOrEqual(lyricsLeft - artRight, 20)
            XCTAssertGreaterThanOrEqual(playerTop - artworkBottom, 20)
            XCTAssertLessThanOrEqual(playerBottom, size.height)
        }
    }

    func testExpandedForegroundUsesTheEntireDisplayAndCompactPanelIsSmall() {
        for size in [CGSize(width: 1024, height: 768), CGSize(width: 1512, height: 982), CGSize(width: 1920, height: 1080)] {
            let layout = LockScreenMediaLayout(screenSize: size, showsLyrics: true)
            let expanded = layout.foregroundFrame(isExpanded: true)
            XCTAssertEqual(expanded, CGRect(origin: .zero, size: size))
            XCTAssertEqual(layout.foregroundFrame(isExpanded: false).size, CGSize(width: 340, height: 180))
        }
    }

    func testImmersiveLyricsUseScreenWidthAndHeightAndKeepCloseButtonVisible() {
        for size in [CGSize(width: 1024, height: 768), CGSize(width: 1512, height: 982), CGSize(width: 1920, height: 1080), CGSize(width: 2560, height: 1440)] {
            let layout = LockScreenMediaLayout(screenSize: size, showsLyrics: true)
            XCTAssertGreaterThan(layout.lyricsWidth, size.width * 0.4)
            XCTAssertGreaterThan(layout.lyricsHeight, size.height * 0.75)
            XCTAssertGreaterThanOrEqual(layout.lyricsFontSize, 32)
            XCTAssertTrue(layout.foregroundFrame(isExpanded: true).contains(layout.collapseButtonFrame))
            XCTAssertLessThanOrEqual(size.height / 2 + layout.playerY + layout.playerHeight / 2, size.height - layout.bottomInset + 0.1)
        }
    }

    func testAmbientMeshCoversEdgesAndIsStaticWhenMotionIsDisabled() {
        let still = LockScreenAmbientMesh.points(at: 0, animated: false)
        XCTAssertEqual(still, LockScreenAmbientMesh.points(at: 900, animated: false))
        XCTAssertNotEqual(still, LockScreenAmbientMesh.points(at: 11, animated: true))
        for time in stride(from: 0.0, through: 900.0, by: 11) {
            let points = LockScreenAmbientMesh.points(at: time, animated: true)
            XCTAssertEqual(points[0], [0, 0]); XCTAssertEqual(points[2], [1, 0])
            XCTAssertEqual(points[6], [0, 1]); XCTAssertEqual(points[8], [1, 1])
            XCTAssertTrue(points.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
        }
    }

    @MainActor
    func testExpansionStartsWithArtworkAndCloseAlwaysReturnsToCompact() {
        let animator = LockScreenPanelAnimator()
        XCTAssertEqual(animator.mode, .compact)
        animator.expandArtwork()
        XCTAssertEqual(animator.mode, .artwork)
        animator.toggleLyrics()
        XCTAssertEqual(animator.mode, .lyrics)
        animator.toggleLyrics()
        XCTAssertEqual(animator.mode, .artwork)
        animator.closeExpandedPlayer()
        XCTAssertEqual(animator.mode, .compact)
        animator.expandArtwork()
        animator.toggleLyrics()
        animator.closeExpandedPlayer()
        animator.expandArtwork()
        XCTAssertEqual(animator.mode, .artwork)
        animator.toggleLyrics()
        animator.disableLyrics()
        XCTAssertEqual(animator.mode, .artwork)
    }

    func testArtworkModeCoversDisplayAndKeepsCloseControlVisible() {
        for size in [CGSize(width: 1024, height: 768), CGSize(width: 1200, height: 760), CGSize(width: 1512, height: 982)] {
            let layout = LockScreenMediaLayout(screenSize: size, showsLyrics: false)
            let frame = layout.foregroundFrame(isExpanded: true)
            XCTAssertTrue(frame.contains(layout.collapseButtonFrame))
            XCTAssertEqual(frame, CGRect(origin: .zero, size: size))
            XCTAssertGreaterThanOrEqual(size.height / 2 + layout.artworkY - layout.artworkSize / 2, layout.topInset)
            XCTAssertGreaterThanOrEqual(layout.playerWidth, 280)
        }
    }

    func testSmallLandscapeAndPortraitScreensFitBothLyricsAndControls() {
        for size in [CGSize(width: 735, height: 490), CGSize(width: 390, height: 844),
                     CGSize(width: 768, height: 1024)] {
            let layout = LockScreenMediaLayout(screenSize: size, showsLyrics: true)
            func rect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> CGRect {
                CGRect(x: size.width / 2 + x - width / 2, y: size.height / 2 + y - height / 2,
                       width: width, height: height)
            }
            let player = rect(x: layout.playerX, y: layout.playerY, width: layout.playerWidth, height: layout.playerHeight)
            let lyrics = rect(x: layout.lyricsX, y: layout.lyricsY, width: layout.lyricsWidth, height: layout.lyricsHeight)
            let cover = rect(x: layout.artworkX, y: layout.artworkY, width: layout.artworkSize, height: layout.artworkSize)
            let canvas = CGRect(origin: .zero, size: size)
            XCTAssertTrue(canvas.contains(player) && canvas.contains(lyrics) && canvas.contains(cover))
            XCTAssertFalse(player.intersects(lyrics))
            XCTAssertFalse(cover.intersects(lyrics))
            XCTAssertFalse(player.intersects(cover))
        }
    }

    func testLyricsAndCloseStayInTheSamePlaceAcrossBothFullScreenModes() {
        for size in [CGSize(width: 735, height: 490), CGSize(width: 1200, height: 760),
                     CGSize(width: 1512, height: 982), CGSize(width: 2560, height: 1440)] {
            let album = LockScreenMediaLayout(screenSize: size, showsLyrics: false)
            let lyrics = LockScreenMediaLayout(screenSize: size, showsLyrics: true)
            XCTAssertEqual(album.collapseButtonFrame, lyrics.collapseButtonFrame)
            XCTAssertEqual(album.lyricsButtonFrame, lyrics.lyricsButtonFrame)
            XCTAssertTrue(CGRect(origin: .zero, size: size).contains(album.lyricsButtonFrame))
            XCTAssertFalse(album.lyricsButtonFrame.intersects(album.collapseButtonFrame))
            XCTAssertEqual(album.lyricsButtonFrame.height, 44)
        }
    }

    func testArtworkFooterNeverOverlapsCoverAndFitsShortOrNarrowScreens() {
        for size in [CGSize(width: 390, height: 844), CGSize(width: 735, height: 490),
                     CGSize(width: 1024, height: 768), CGSize(width: 1200, height: 760),
                     CGSize(width: 1512, height: 982), CGSize(width: 2560, height: 1440)] {
            let layout = LockScreenMediaLayout(screenSize: size, showsLyrics: false)
            let coverBottom = size.height / 2 + layout.artworkY + layout.artworkSize / 2
            let footerTop = size.height - layout.bottomInset - layout.artworkFooterHeight
            XCTAssertGreaterThanOrEqual(footerTop - coverBottom, 23.9)
            XCTAssertGreaterThanOrEqual(size.height / 2 + layout.artworkY - layout.artworkSize / 2, layout.topInset - 0.1)
            XCTAssertGreaterThanOrEqual(layout.artworkControlsWidth, 200)
            XCTAssertLessThanOrEqual(layout.artworkControlsWidth + 2 * layout.actionInset, size.width)
            if !layout.usesStackedArtworkFooter {
                let titleRight = layout.actionInset + 20 + layout.artworkMetadataWidth
                let controlsLeft = (size.width - layout.artworkControlsWidth) / 2
                XCTAssertLessThanOrEqual(titleRight, controlsLeft)
            }
        }
    }

    func testArtworkIsCenteredWithoutLyrics() {
        let layout = LockScreenMediaLayout(screenSize: CGSize(width: 1512, height: 982), showsLyrics: false)
        XCTAssertEqual(layout.artworkX, 0)
        XCTAssertEqual(layout.lyricsWidth, 0)
    }
}
