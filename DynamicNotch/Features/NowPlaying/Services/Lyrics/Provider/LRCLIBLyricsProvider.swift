import Foundation

@MainActor
final class LRCLIBLyricsProvider: LyricsProviding {
    private enum CacheEntry {
        case found(TrackLyrics)
        case missing

        var lyrics: TrackLyrics? {
            switch self {
            case .found(let lyrics):
                return lyrics
            case .missing:
                return nil
            }
        }
    }

    private struct Response: Decodable {
        let id: Int?
        let trackName: String?
        let artistName: String?
        let albumName: String?
        let duration: Double?
        let instrumental: Bool?
        let plainLyrics: String?
        let syncedLyrics: String?
    }

    private static let baseURL = URL(string: "https://lrclib.net/api")!

    private let session: URLSession
    private let decoder = JSONDecoder()
    private var cache: [String: CacheEntry] = [:]

    init() {
        let configuration = URLSessionConfiguration.default
        // Successful/missing tracks are cached above. Never reuse a cached HTTP failure
        // when retrying a lookup or when the user asks to refresh lyrics.
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 45
        session = URLSession(configuration: configuration)
    }

    func lyrics(for snapshot: NowPlayingSnapshot) async throws -> TrackLyrics? {
        guard let trackKey = snapshot.lyricsLookupKey else { return nil }

        if let cached = cache[trackKey] {
            return cached.lyrics
        }

        if let exactLyrics = try await fetchExactLyrics(for: snapshot, trackKey: trackKey) {
            cache[trackKey] = .found(exactLyrics)
            return exactLyrics
        }

        let searchedLyrics = try await searchLyrics(for: snapshot, trackKey: trackKey)
        cache[trackKey] = searchedLyrics.map(CacheEntry.found) ?? .missing
        return searchedLyrics
    }

    func invalidateCache(for snapshot: NowPlayingSnapshot) {
        guard let trackKey = snapshot.lyricsLookupKey else { return }
        cache[trackKey] = nil
    }

    private func fetchExactLyrics(for snapshot: NowPlayingSnapshot, trackKey: String) async throws -> TrackLyrics? {
        guard let url = makeURL(
            endpoint: "get",
            queryItems: queryItems(for: snapshot, includeAlbum: true, includeDuration: true)
        ) else {
            return nil
        }

        let data = try await data(from: url, allowsNotFound: true)
        guard let data else { return nil }

        let response = try decoder.decode(Response.self, from: data)
        return makeTrackLyrics(from: response, trackKey: trackKey)
    }

    private func searchLyrics(for snapshot: NowPlayingSnapshot, trackKey: String) async throws -> TrackLyrics? {
        let searchAttempts = [
            queryItems(for: snapshot, includeAlbum: false, includeDuration: true),
            queryItems(for: snapshot, includeAlbum: false, includeDuration: false),
            [
                URLQueryItem(
                    name: "q",
                    value: [snapshot.artist.trimmed, snapshot.title.trimmed]
                        .filter { $0.isEmpty == false }
                        .joined(separator: " ")
                )
            ]
        ]

        for queryItems in searchAttempts {
            guard let url = makeURL(endpoint: "search", queryItems: queryItems) else {
                continue
            }

            guard let data = try await data(from: url, allowsNotFound: false) else {
                continue
            }

            let responses = try decoder.decode([Response].self, from: data)
            if let lyrics = bestResponse(from: responses, for: snapshot)
                .flatMap({ makeTrackLyrics(from: $0, trackKey: trackKey) }) {
                return lyrics
            }
        }

        return nil
    }

    private func makeURL(endpoint: String, queryItems: [URLQueryItem]) -> URL? {
        var components = URLComponents(
            url: Self.baseURL.appendingPathComponent(endpoint),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = queryItems
        return components?.url
    }

    private func queryItems(for snapshot: NowPlayingSnapshot, includeAlbum: Bool, includeDuration: Bool) -> [URLQueryItem] {
        var items = [
            URLQueryItem(name: "track_name", value: snapshot.title.trimmed),
            URLQueryItem(name: "artist_name", value: snapshot.artist.trimmed)
        ]

        if includeAlbum, snapshot.album.trimmed.isEmpty == false {
            items.append(URLQueryItem(name: "album_name", value: snapshot.album.trimmed))
        }

        if includeDuration, snapshot.duration > 0 {
            items.append(URLQueryItem(name: "duration", value: "\(Int(snapshot.duration.rounded()))"))
        }

        return items
    }

    private func data(from url: URL, allowsNotFound: Bool) async throws -> Data? {
        var request = URLRequest(url: url)
        request.setValue(
            "NotchFlow/1.0",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        switch httpResponse.statusCode {
        case 200..<300:
            return data
        case 404 where allowsNotFound:
            return nil
        default:
            throw URLError(.badServerResponse, userInfo: ["HTTPStatusCode": httpResponse.statusCode])
        }
    }

    private func bestResponse(from responses: [Response], for snapshot: NowPlayingSnapshot) -> Response? {
        responses
            .filter { response in
                response.instrumental == true ||
                response.syncedLyrics?.trimmed.isEmpty == false ||
                response.plainLyrics?.trimmed.isEmpty == false
            }
            .max { first, second in
                matchScore(first, snapshot: snapshot) < matchScore(second, snapshot: snapshot)
            }
    }

    private func matchScore(_ response: Response, snapshot: NowPlayingSnapshot) -> Int {
        let title = snapshot.title.normalizedLyricsSearchText
        let artist = snapshot.artist.normalizedLyricsSearchText
        let album = snapshot.album.normalizedLyricsSearchText
        let responseTitle = response.trackName?.normalizedLyricsSearchText ?? ""
        let responseArtist = response.artistName?.normalizedLyricsSearchText ?? ""
        let responseAlbum = response.albumName?.normalizedLyricsSearchText ?? ""
        let durationDelta = response.duration.map {
            abs(Int($0.rounded()) - Int(snapshot.duration.rounded()))
        }

        var score = 0
        if responseTitle == title { score += 120 }
        if responseArtist == artist { score += 90 }
        if album.isEmpty == false, responseAlbum == album { score += 35 }
        if response.syncedLyrics?.trimmed.isEmpty == false { score += 20 }
        if let durationDelta {
            if durationDelta <= 2 { score += 24 }
            else if durationDelta <= 6 { score += 12 }
        }

        return score
    }

    private func makeTrackLyrics(from response: Response, trackKey: String) -> TrackLyrics? {
        if response.instrumental == true {
            return TrackLyrics(
                trackKey: trackKey,
                lines: [], isSynced: false, isInstrumental: true
            )
        }

        let syncedLines = Self.parseSyncedLyrics(response.syncedLyrics)
        if syncedLines.isEmpty == false {
            return TrackLyrics(trackKey: trackKey, lines: syncedLines, isSynced: true)
        }

        let plainLines = Self.parsePlainLyrics(response.plainLyrics)
        if plainLines.isEmpty == false {
            return TrackLyrics(trackKey: trackKey, lines: plainLines, isSynced: false)
        }

        return nil
    }

    private static func parsePlainLyrics(_ lyrics: String?) -> [LyricLine] {
        lyrics?
            .components(separatedBy: .newlines)
            .map(\.trimmed)
            .filter { $0.isEmpty == false }
            .enumerated()
            .map { index, text in
                LyricLine(id: index, startTime: nil, text: text)
            } ?? []
    }

    private static let lineTimestamp = try! NSRegularExpression(pattern: #"\[(\d{1,3}):([0-5]\d)(?:\.(\d{1,3}))?\]"#)
    private static let segmentTimestamp = try! NSRegularExpression(pattern: #"<(\d{1,3}):([0-5]\d)(?:\.(\d{1,3}))?>"#)

    static func parseSyncedLyrics(_ lyrics: String?) -> [LyricLine] {
        guard let lyrics else { return [] }
        var cues: [LyricLine] = []
        for raw in lyrics.components(separatedBy: .newlines) {
            let ns = raw as NSString
            let stamps = lineTimestamp.matches(in: raw, range: NSRange(location: 0, length: ns.length))
            guard let last = stamps.last else { continue }
            let starts = stamps.compactMap { startTime(from: $0, line: ns) }
            guard let first = starts.first else { continue }
            let payload = ns.substring(from: NSMaxRange(last.range)).trimmed
            let line = parseSegments(in: payload, firstStart: first)
            for start in starts {
                let shift = start - first
                let segments = line.segments.map { LyricLine.Segment(startTime: $0.startTime + shift, text: $0.text) }
                cues.append(LyricLine(id: cues.count, startTime: start, text: line.text, segments: segments,
                                      endTime: line.endTime.map { $0 + shift }))
            }
        }
        // Empty timed lines between verses denote instrumental passages. A file containing
        // only empty cues still needs its plain-lyrics fallback.
        guard cues.contains(where: { !$0.text.isEmpty }) else { return [] }
        return cues.sorted { ($0.startTime ?? 0, $0.id) < ($1.startTime ?? 0, $1.id) }.enumerated().map { index, cue in
            LyricLine(id: index, startTime: cue.startTime, text: cue.text, segments: cue.segments, endTime: cue.endTime)
        }
    }

    private static func parseSegments(in payload: String, firstStart: TimeInterval) -> LyricLine {
        let ns = payload as NSString
        let stamps = segmentTimestamp.matches(in: payload, range: NSRange(location: 0, length: ns.length))
        guard !stamps.isEmpty else { return LyricLine(id: 0, startTime: firstStart, text: payload) }
        var position = 0
        var current = firstStart
        var valid = true
        var segments: [LyricLine.Segment] = []
        for stamp in stamps {
            let text = ns.substring(with: NSRange(location: position, length: stamp.range.location - position))
            if !text.isEmpty { segments.append(.init(startTime: current, text: text)) }
            if let next = startTime(from: stamp, line: ns) {
                if next < current { valid = false }
                current = next
            }
            position = NSMaxRange(stamp.range)
        }
        let tail = ns.substring(from: position)
        if !tail.isEmpty { segments.append(.init(startTime: current, text: tail)) }
        return LyricLine(id: 0, startTime: firstStart, text: segments.map(\.text).joined().trimmed,
                         segments: valid ? segments : [], endTime: valid && tail.isEmpty ? current : nil)
    }

    private static func startTime(from match: NSTextCheckingResult, line: NSString) -> TimeInterval? {
        guard
            let minutes = integerValue(in: match.range(at: 1), line: line),
            let seconds = integerValue(in: match.range(at: 2), line: line)
        else {
            return nil
        }

        let fraction = fractionalSeconds(in: match.range(at: 3), line: line)
        return TimeInterval((minutes * 60) + seconds) + fraction
    }

    private static func integerValue(in range: NSRange, line: NSString) -> Int? {
        guard range.location != NSNotFound else { return nil }
        return Int(line.substring(with: range))
    }

    private static func fractionalSeconds(in range: NSRange, line: NSString) -> TimeInterval {
        guard range.location != NSNotFound else { return 0 }

        let rawValue = line.substring(with: range)
        guard let value = Double(rawValue) else { return 0 }

        switch rawValue.count {
        case 1:
            return value / 10
        case 2:
            return value / 100
        default:
            return value / 1000
        }
    }
}

extension NowPlayingSnapshot {
    var lyricsLookupKey: String? {
        let title = title.trimmed
        let artist = artist.trimmed

        guard title.isEmpty == false, artist.isEmpty == false else {
            return nil
        }

        return [
            title.normalizedLyricsSearchText,
            artist.normalizedLyricsSearchText,
            album.normalizedLyricsSearchText,
            "\(Int(duration.rounded()))"
        ].joined(separator: "|")
    }
}

private extension String {
    var normalizedLyricsSearchText: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "’", with: "'")
    }
}
