import Foundation

/// A single timed line of synced lyrics.
struct LrcLine: Equatable, Sendable, Identifiable {
    let id = UUID()
    let time: Double  // seconds from track start
    let text: String

    static func == (lhs: LrcLine, rhs: LrcLine) -> Bool {
        lhs.time == rhs.time && lhs.text == rhs.text
    }
}
