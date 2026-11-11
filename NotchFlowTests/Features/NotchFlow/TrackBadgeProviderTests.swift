import XCTest
@testable import NotchFlow

final class TrackBadgeProviderTests: XCTestCase {
    func testExplicitMatchesTitleAndArtist() {
        typealias T = TrackBadgeProvider.CatalogTrack
        let results = [
            T(title: "HUMBLE. (Radio Edit)", artist: "Kendrick Lamar", album: "Singles", explicitness: "notExplicit"),
            T(title: "HUMBLE.", artist: "Kendrick Lamar", album: "DAMN. (Clean)", explicitness: "cleaned"),
            T(title: "HUMBLE.", artist: "Kendrick Lamar", album: "DAMN.", explicitness: "explicit")
        ]
        XCTAssertEqual(TrackBadgeProvider.explicitness(in: results, title: "HUMBLE.", artist: "Kendrick Lamar", album: "DAMN."), true)
        XCTAssertEqual(TrackBadgeProvider.explicitness(in: results, title: "HUMBLE.", artist: "Kendrick Lamar", album: "DAMN. (Clean)"), false)
        XCTAssertEqual(TrackBadgeProvider.explicitness(in: [T(title: "Hello", artist: "Adele", explicitness: "notExplicit")],
                                                       title: "Hello", artist: "Adele"), false)
        XCTAssertNil(TrackBadgeProvider.explicitness(in: [T(title: "Other", artist: "Someone", explicitness: "explicit")],
                                                     title: "Hello", artist: "Adele"))
    }

    func testFormatFromMusicReport() {
        XCTAssertEqual(TrackBadgeProvider.format(fromMusicReport: "Apple Lossless audio file|44100|1411"), .lossless)
        XCTAssertEqual(TrackBadgeProvider.format(fromMusicReport: "Apple Lossless audio file|96000|4608"), .hiResLossless)
        XCTAssertNil(TrackBadgeProvider.format(fromMusicReport: "Apple Music AAC audio file|44100|256"))
        XCTAssertNil(TrackBadgeProvider.format(fromMusicReport: "garbage"))
    }
}
