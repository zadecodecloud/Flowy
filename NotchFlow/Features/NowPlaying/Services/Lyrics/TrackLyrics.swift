import Foundation

struct TrackLyrics: Equatable, Sendable {
    let trackKey: String
    let lines: [LyricLine]
    let isSynced: Bool
    var isInstrumental = false

    /// Timed providers sort cues by start time. No line is active during the intro.
    func activeLineIndex(at elapsedTime: TimeInterval) -> Int? {
        guard isSynced, elapsedTime.isFinite else { return nil }
        var lower = 0
        var upper = lines.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if let start = lines[middle].startTime, start <= elapsedTime {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return lower == 0 ? nil : lower - 1
    }

    /// Schedule line changes against the playback clock. Paused/plain lyrics need no ticks.
    func cueDates(for snapshot: NowPlayingSnapshot, from now: Date) -> [Date] {
        guard isSynced, snapshot.isPlaying, snapshot.playbackRate.isFinite else { return [now] }
        let position = snapshot.elapsedTime(at: now)
        let future = lines.compactMap { line -> Date? in
            guard let start = line.startTime, start > position,
                  snapshot.duration <= 0 || start <= snapshot.duration else { return nil }
            // Slightly beyond the boundary so floating-point rounding cannot select the old line.
            return now.addingTimeInterval((start - position) / snapshot.playbackRate + 0.002)
        }
        return [now] + future
    }
}
