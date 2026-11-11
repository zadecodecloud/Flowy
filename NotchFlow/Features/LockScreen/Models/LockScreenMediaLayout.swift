import CoreGraphics

/// One layout for both full-screen modes, with controls kept clear of the cover.
struct LockScreenMediaLayout {
    let screenSize: CGSize
    let showsLyrics: Bool
    var wideLyrics = false
    private var referenceLayout: Bool { wideLyrics && showsLyrics && !portrait }

    private var width: CGFloat { max(1, screenSize.width) }
    private var height: CGFloat { max(1, screenSize.height) }
    private var portrait: Bool { showsLyrics && width < height * 0.90 }
    var padding: CGFloat { min(180, width * (portrait ? 0.045 : 0.1083)) }
    var topInset: CGFloat { min(96, max(70, height * 0.065)) }
    var bottomInset: CGFloat { min(56, max(18, height * 0.064)) }
    private var contentHeight: CGFloat { max(1, height - topInset - bottomInset) }
    private var gap: CGFloat { portrait ? min(34, width * 0.045) : min(160, width * (referenceLayout ? 0.075 : 0.0958)) }
    private var artworkColumnWidth: CGFloat { min(720, width * (portrait ? 0.25 : (referenceLayout ? 0.29 : 0.2583))) }
    private var artworkGap: CGFloat { referenceLayout ? 10 : (height < 620 ? 12 : 20) }
    var playerHeight: CGFloat { referenceLayout ? 104 : 174 }
    var artworkSize: CGFloat {
        if portrait { return min(220, artworkColumnWidth) }
        if !showsLyrics {
            // Leave a real gap above the footer, including short external displays.
            let available = height - topInset - artworkFooterHeight - bottomInset - 24
            return max(1, min(width * 0.75, height * 0.523, 820, available))
        }
        return max(1, min(artworkColumnWidth, contentHeight - playerHeight - artworkGap))
    }
    var playerWidth: CGFloat {
        if portrait { return max(1, width - 2 * padding - artworkSize - gap) }
        if referenceLayout { return artworkSize }
        return min(width - 2 * padding, max(224, min(artworkSize, 420)))
    }
    var artworkX: CGFloat { showsLyrics ? padding + artworkSize / 2 - width / 2 : 0 }
    var playerX: CGFloat { portrait ? width / 2 - padding - playerWidth / 2 : artworkX }
    private var columnTop: CGFloat {
        topInset + max(0, (contentHeight - artworkSize - artworkGap - playerHeight) / 2)
    }
    var artworkY: CGFloat {
        if !showsLyrics {
            let availableBottom = height - bottomInset - artworkFooterHeight - 24
            return max(topInset + artworkSize / 2, min(height * 0.453, availableBottom - artworkSize / 2)) - height / 2
        }
        if portrait { return topInset + max(playerHeight, artworkSize) / 2 - height / 2 }
        return columnTop + artworkSize / 2 - height / 2
    }
    var playerY: CGFloat {
        portrait ? artworkY : columnTop + artworkSize + artworkGap + playerHeight / 2 - height / 2
    }
    private var lyricsLeft: CGFloat { portrait ? padding : padding + artworkColumnWidth + gap }
    private var lyricsTop: CGFloat { portrait ? topInset + max(playerHeight, artworkSize) + gap : (referenceLayout ? height * 0.14 : topInset) }
    var lyricsWidth: CGFloat { showsLyrics ? max(1, width - lyricsLeft - padding) : 0 }
    var lyricsHeight: CGFloat { max(1, height - lyricsTop - bottomInset) }
    var lyricsX: CGFloat { lyricsLeft + lyricsWidth / 2 - width / 2 }
    var lyricsY: CGFloat { lyricsTop + lyricsHeight / 2 - height / 2 }
    var lyricsFontSize: CGFloat {
        if referenceLayout { return min(48, max(24, width * 0.0267)) }
        return min(58, max(portrait ? 26 : 32, (portrait ? width * 0.065 : width * 0.0283))) }

    var actionInset: CGFloat { min(44, max(20, width * 0.0233)) }
    var collapseButtonFrame: CGRect { CGRect(x: width - actionInset - 44, y: 20, width: 44, height: 44) }
    var lyricsButtonFrame: CGRect { collapseButtonFrame.offsetBy(dx: -46, dy: 0) }
    var usesStackedArtworkFooter: Bool { width < 900 }
    var artworkFooterHeight: CGFloat { usesStackedArtworkFooter ? 174 : 114 }
    var artworkControlsWidth: CGFloat { min(320, width - 2 * actionInset) }
    var artworkMetadataWidth: CGFloat { max(1, min(280, (width - artworkControlsWidth) / 2 - 2 * actionInset)) }

    func coverFrame(isExpanded: Bool, verticalOffset: Double = 0) -> CGRect {
        if isExpanded {
            return CGRect(x: width / 2 + artworkX - artworkSize / 2,
                          y: height / 2 + artworkY - artworkSize / 2,
                          width: artworkSize, height: artworkSize)
        }
        let card = foregroundFrame(isExpanded: false, verticalOffset: verticalOffset)
        return CGRect(x: card.minX + 18, y: card.minY + 18, width: 60, height: 60)
    }

    func foregroundFrame(isExpanded: Bool, verticalOffset: Double = 0) -> CGRect {
        if isExpanded { return CGRect(origin: .zero, size: screenSize) }
        return CGRect(x: (width - 340) / 2, y: (height - 180) / 2 + 170 + verticalOffset,
                      width: 340, height: 180)
    }
}
