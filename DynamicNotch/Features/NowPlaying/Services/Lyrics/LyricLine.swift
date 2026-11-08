import Foundation

struct LyricLine: Identifiable, Equatable, Sendable {
    struct Segment: Equatable, Sendable {
        let startTime: TimeInterval
        let text: String
    }

    let id: Int
    let startTime: TimeInterval?
    let text: String
    var segments: [Segment] = []
    var endTime: TimeInterval? = nil
}
