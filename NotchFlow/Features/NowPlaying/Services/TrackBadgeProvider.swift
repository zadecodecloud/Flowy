import Foundation
import Combine

/// What to show next to the track title in the Music player.
enum NowPlayingTrackBadge: String, CaseIterable, StoredSettingValue {
    case none
    /// The "E" mark for explicit tracks (looked up in the iTunes catalog by title and artist).
    case explicit
    /// Lossless / Hi-Res Lossless (Apple Music only; read from the Music app's current track).
    case format
}

/// Audio quality of the current Apple Music track, as far as the Music app reports it.
enum TrackAudioFormat: Equatable {
    case lossless
    case hiResLossless

    /// Text shown in the player badge.
    var shortLabel: String {
        switch self {
        case .lossless: return "Lossless"
        case .hiResLossless: return "Hi-Res"
        }
    }

    var label: String {
        switch self {
        case .lossless: return "Lossless"
        case .hiResLossless: return "Hi-Res Lossless"
        }
    }
}

/// Looks up badge data for the current track. Results are cached per track; nothing is looked up
/// unless the user picked that badge in Settings.
@MainActor
final class TrackBadgeProvider: ObservableObject {
    static let shared = TrackBadgeProvider()

    @Published private(set) var isExplicit = false
    @Published private(set) var audioFormat: TrackAudioFormat?

    private var explicitCache: [String: Bool] = [:]
    private var currentKey = ""
    private var task: Task<Void, Never>?

    /// Call when the track or the badge setting changes.
    func update(title: String, artist: String, album: String = "", bundleIdentifier: String?, badge: NowPlayingTrackBadge) {
        let key = "\(badge.rawValue)|\(title.lowercased())|\(artist.lowercased())|\(album.lowercased())"
        guard key != currentKey else { return }
        currentKey = key
        task?.cancel()
        isExplicit = false
        audioFormat = nil
        guard !title.isEmpty, !AppEnvironment.isRunningTests else { return }

        switch badge {
        case .none:
            return
        case .explicit:
            let cacheKey = "\(title.lowercased())|\(artist.lowercased())|\(album.lowercased())"
            if let cached = explicitCache[cacheKey] { isExplicit = cached; return }
            task = Task { [weak self] in
                let value = await Self.lookupExplicit(title: title, artist: artist, album: album)
                guard !Task.isCancelled, let self, let value else { return }
                self.explicitCache[cacheKey] = value
                self.isExplicit = value
            }
        case .format:
            guard bundleIdentifier == "com.apple.Music" else { return }
            task = Task { [weak self] in
                let format = await Self.readMusicFormat()
                guard !Task.isCancelled, let self else { return }
                self.audioFormat = format
            }
        }
    }

    // MARK: Explicit (iTunes Search API, public, no account)

    private struct SearchResponse: Decodable {
        struct Item: Decodable {
            let trackName: String?
            let artistName: String?
            let collectionName: String?
            let trackExplicitness: String?
        }
        let results: [Item]
    }

    nonisolated static func lookupExplicit(title: String, artist: String, album: String) async -> Bool? {
        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            .init(name: "term", value: "\(artist) \(title)"),
            .init(name: "entity", value: "song"),
            .init(name: "limit", value: "10")
        ]
        guard let url = components.url,
              let (data, _) = try? await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 8)),
              let response = try? JSONDecoder().decode(SearchResponse.self, from: data) else { return nil }
        return explicitness(in: response.results.map { .init(title: $0.trackName, artist: $0.artistName,
                                                              album: $0.collectionName, explicitness: $0.trackExplicitness) },
                            title: title, artist: artist, album: album)
    }

    struct CatalogTrack {
        var title: String?
        var artist: String?
        var album: String?
        var explicitness: String?
    }

    /// Picks the best catalog match: exact title beats a prefix ("Song (Radio Edit)"), and the same
    /// album tells the explicit and clean versions apart. Nil when nothing matches.
    nonisolated static func explicitness(in results: [CatalogTrack], title: String, artist: String, album: String = "") -> Bool? {
        func norm(_ s: String) -> String {
            s.lowercased().folding(options: .diacriticInsensitive, locale: nil)
                .components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        }
        let wantTitle = norm(title), wantArtist = norm(artist), wantAlbum = norm(album)
        var best: (score: Int, explicit: Bool)?
        for item in results {
            guard let name = item.title, let by = item.artist else { continue }
            let n = norm(name), a = norm(by)
            guard wantArtist.isEmpty || a.contains(wantArtist) || wantArtist.contains(a) else { continue }
            var score: Int
            if n == wantTitle { score = 4 } else if n.hasPrefix(wantTitle) || wantTitle.hasPrefix(n) { score = 1 } else { continue }
            if !wantAlbum.isEmpty, let col = item.album, norm(col) == wantAlbum { score += 2 }
            if best == nil || score > best!.score { best = (score, item.explicitness == "explicit") }
        }
        return best?.explicit
    }

    // MARK: Format (Music app via AppleScript; macOS asks once for permission to control Music)

    nonisolated static func readMusicFormat() async -> TrackAudioFormat? {
        await Task.detached(priority: .utility) {
            let source = """
            tell application "Music"
                if player state is stopped then return ""
                set t to current track
                return (kind of t as text) & "|" & ((sample rate of t) as text) & "|" & ((bit rate of t) as text)
            end tell
            """
            var error: NSDictionary?
            guard let output = NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue,
                  error == nil else { return nil }
            return format(fromMusicReport: output)
        }.value
    }

    /// `kind|sampleRate|bitRate` from the Music app → badge. Lossless is ALAC or a lossless kind;
    /// Hi-Res when the sample rate is above 48 kHz.
    nonisolated static func format(fromMusicReport report: String) -> TrackAudioFormat? {
        let parts = report.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3 else { return nil }
        let kind = parts[0].lowercased()
        let sampleRate = Double(parts[1].replacingOccurrences(of: ",", with: ".")) ?? 0
        let isLossless = kind.contains("lossless") || kind.contains("alac") || kind.contains("aiff") || kind.contains("wav")
        guard isLossless else { return nil }
        return sampleRate > 48_000 ? .hiResLossless : .lossless
    }
}
