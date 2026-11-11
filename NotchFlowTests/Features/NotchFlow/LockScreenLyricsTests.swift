import XCTest
@testable import NotchFlow

@MainActor
final class LockScreenLyricsTests: XCTestCase {
    func testEnhancedCuesPreserveWordsRepeatsAndInstrumentalBreaks() throws {
        let lines = LRCLIBLyricsProvider.parseSyncedLyrics("""
        [ar:Preview]
        [00:03.00][00:23.00]<00:03.00>Phố <00:04.25>lên đèn<00:06.90>
        [00:08.00]
        [00:11.00]Câu tiếp theo
        """)
        XCTAssertEqual(lines.map(\.text), ["Phố lên đèn", "", "Câu tiếp theo", "Phố lên đèn"])
        XCTAssertEqual(lines[0].segments.map(\.startTime), [3, 4.25])
        XCTAssertEqual(lines[3].segments.map(\.startTime), [23, 24.25])
        XCTAssertEqual(try XCTUnwrap(lines[3].endTime), 26.9, accuracy: 0.001)
        let lyrics = TrackLyrics(trackKey: "fixture", lines: lines, isSynced: true)
        XCTAssertNil(lyrics.activeLineIndex(at: 2.99))
        XCTAssertEqual(lyrics.activeLineIndex(at: 3), 0)
        XCTAssertEqual(lyrics.activeLineIndex(at: 8.0), 1)
        XCTAssertEqual(lyrics.activeLineIndex(at: 24.3), 3)
    }

    func testLineOnlyAndMalformedWordTimingNeverInventWordCues() {
        let lines = LRCLIBLyricsProvider.parseSyncedLyrics("[00:01.00]Câu một\n[00:05.00]<00:06.00>Câu <00:05.50>hai")
        XCTAssertEqual(lines.map(\.text), ["Câu một", "Câu hai"])
        XCTAssertTrue(lines.allSatisfy { $0.segments.isEmpty })
        XCTAssertTrue(LRCLIBLyricsProvider.parseSyncedLyrics("[00:00.00]").isEmpty)
    }

    func testCueScheduleUsesPlaybackRateAndHasNoPeriodicTicksOnPause() {
        let now = Date()
        let lines = LRCLIBLyricsProvider.parseSyncedLyrics("[00:00.00]First\n[00:10.00]Second\n[00:20.00]Third")
        let lyrics = TrackLyrics(trackKey: "fixture", lines: lines, isSynced: true)
        let snapshot = NowPlayingSnapshot(title: "Fixture", artist: "Preview", album: "", duration: 80,
                                          elapsedTime: 8, playbackRate: 2, artworkData: nil, refreshedAt: now)
        let dates = lyrics.cueDates(for: snapshot, from: now)
        XCTAssertEqual(dates.count, 3)
        XCTAssertEqual(dates[1].timeIntervalSince(now), 1, accuracy: 0.01)
        XCTAssertEqual(dates[2].timeIntervalSince(now), 6, accuracy: 0.01)
        XCTAssertEqual(lyrics.cueDates(for: snapshot.settingPlaybackRate(0), from: now), [now])
    }

    func testLiveLRCLIBLookupWhenExplicitlyEnabled() async throws {
        guard ProcessInfo.processInfo.environment["NOTCHFLOW_LIVE_LYRICS_SMOKE"] == "1" else {
            throw XCTSkip("Live network smoke test is opt-in")
        }
        let provider = LRCLIBLyricsProvider()
        let snapshot = makeNowPlayingSnapshot(title: "Yesterday", artist: "The Beatles", album: "Help!", duration: 125)
        let lyrics = try await provider.lyrics(for: snapshot)
        let result = try XCTUnwrap(lyrics, "The public smoke-test track should return lyrics")
        XCTAssertFalse(result.lines.isEmpty)
        print("Live LRCLIB smoke: loaded \(result.lines.count) lines; synchronized=\(result.isSynced)")
    }

    func testLyricsLoadOnlyWhenVisibleAndFollowPlaybackTime() async throws {
        let service = FakeNowPlayingService()
        let provider = FixtureLyricsProvider()
        let model = NowPlayingViewModel(service: service, lyricsProvider: provider)
        TestLifetime.retain(model)
        model.startMonitoring()
        service.publish(makeNowPlayingSnapshot(playbackRate: 1))
        XCTAssertEqual(provider.requestCount, 0)
        model.setLyricsPresentationActive(true)
        for _ in 0..<50 {
            if case .loaded = model.lyricsState { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        guard case .loaded(let lyrics) = model.lyricsState else { return XCTFail("Lyrics did not load") }
        XCTAssertEqual(provider.requestCount, 1)
        XCTAssertTrue(lyrics.isSynced)
        XCTAssertEqual(lyrics.activeLineIndex(at: 1), 0)
        XCTAssertEqual(lyrics.activeLineIndex(at: 11), 1)
        XCTAssertEqual(lyrics.activeLineIndex(at: 21), 2)
        model.setLyricsPresentationActive(false)
        model.stopMonitoring()
    }

    func testMissingLyricsHasExplicitEmptyState() async throws {
        let service = FakeNowPlayingService()
        let provider = FixtureLyricsProvider()
        provider.returnsNoLyrics = true
        let model = NowPlayingViewModel(service: service, lyricsProvider: provider)
        TestLifetime.retain(model)
        model.startMonitoring()
        service.publish(makeNowPlayingSnapshot())
        model.setLyricsPresentationActive(true)
        for _ in 0..<50 {
            if case .notFound = model.lyricsState { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        guard case .notFound = model.lyricsState else { return XCTFail("Expected unavailable lyrics state") }
        model.setLyricsPresentationActive(false)
        model.stopMonitoring()
    }
    func testSeekPauseAndTrackChangeKeepLyricsAttachedToCurrentTrack() async throws {
        let service = FakeNowPlayingService()
        let provider = FixtureLyricsProvider()
        let model = NowPlayingViewModel(service: service, lyricsProvider: provider)
        TestLifetime.retain(model)
        model.startMonitoring()
        model.setLyricsPresentationActive(true)
        service.publish(makeNowPlayingSnapshot(title: "First Song"))
        await assertEventually { await MainActor.run { if case .loaded = model.lyricsState { return true }; return false } }
        model.seek(to: 11)
        model.pause()
        guard case .loaded(let first) = model.lyricsState else { return XCTFail("Missing lyrics") }
        XCTAssertEqual(first.activeLineIndex(at: model.elapsedTime(at: .now)), 1)
        XCTAssertFalse(model.snapshot!.isPlaying)
        let firstKey = first.trackKey
        service.publish(makeNowPlayingSnapshot(title: "Second Song"))
        await assertEventually { await MainActor.run {
            if case .loaded(let value) = model.lyricsState { return value.trackKey != firstKey }
            return false
        } }
        XCTAssertEqual(provider.requestCount, 2)
        model.stopMonitoring()
        XCTAssertEqual(model.lyricsState, .idle)
    }

    func testTransientFailureRetriesAndPermanentFailureHasExplicitState() async {
        let service = FakeNowPlayingService()
        let provider = FixtureLyricsProvider()
        provider.failuresRemaining = 1
        let model = NowPlayingViewModel(service: service, lyricsProvider: provider)
        TestLifetime.retain(model)
        model.lyricsRetryDelays = [0.01]
        model.startMonitoring()
        service.publish(makeNowPlayingSnapshot())
        model.setLyricsPresentationActive(true)
        await assertEventually { await MainActor.run { if case .loaded = model.lyricsState { return true }; return false } }
        XCTAssertEqual(provider.requestCount, 2)
        provider.failuresRemaining = 10
        model.reloadLyrics()
        await assertEventually { await MainActor.run { if case .failed = model.lyricsState { return true }; return false } }
        XCTAssertEqual(provider.requestCount, 4)
        model.stopMonitoring()
    }

    func testHiddenLyricsCancelRetriesAndResumeOnReopen() async throws {
        let service = FakeNowPlayingService()
        let provider = FixtureLyricsProvider()
        provider.failuresRemaining = 1
        let model = NowPlayingViewModel(service: service, lyricsProvider: provider)
        TestLifetime.retain(model)
        model.lyricsRetryDelays = [0.1]
        model.startMonitoring()
        service.publish(makeNowPlayingSnapshot())
        model.setLyricsPresentationActive(true)
        await assertEventually { await MainActor.run { provider.requestCount == 1 } }
        model.setLyricsPresentationActive(false)
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(provider.requestCount, 1)
        XCTAssertEqual(model.lyricsState, .idle)
        model.setLyricsPresentationActive(true)
        await assertEventually { await MainActor.run { if case .loaded = model.lyricsState { return true }; return false } }
        XCTAssertEqual(provider.requestCount, 2)
        model.stopMonitoring()
    }



}

@MainActor
private final class FixtureLyricsProvider: LyricsProviding {
    var requestCount = 0
    var returnsNoLyrics = false
    var failuresRemaining = 0
    func lyrics(for snapshot: NowPlayingSnapshot) async throws -> TrackLyrics? {
        requestCount += 1
        if failuresRemaining > 0 { failuresRemaining -= 1; throw URLError(.notConnectedToInternet) }
        guard !returnsNoLyrics, let key = snapshot.lyricsLookupKey else { return nil }
        return TrackLyrics(trackKey: key, lines: [
            LyricLine(id: 0, startTime: 0, text: "First line"),
            LyricLine(id: 1, startTime: 10, text: "Second line"),
            LyricLine(id: 2, startTime: 20, text: "Third line")
        ], isSynced: true)
    }
}
