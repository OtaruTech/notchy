import Foundation

struct NowPlayingVM: Equatable, Sendable {
    var title: String
    var artist: String
    var album: String
    var elapsed: Double
    var duration: Double
    var isPlaying: Bool
    var artworkData: Data?
    var sourceBundleId: String?
    /// Wall-clock timestamp when this snapshot was produced — used to interpolate
    /// elapsed time between media-control events so the scrubber moves smoothly.
    var snapshotDate: Date

    static func from(_ info: NowPlayingInfo) -> NowPlayingVM {
        NowPlayingVM(
            title: info.title,
            artist: info.artist ?? "",
            album: info.album ?? "",
            elapsed: info.elapsed ?? 0,
            duration: info.duration ?? 0,
            isPlaying: info.isPlaying,
            artworkData: info.artworkData,
            sourceBundleId: info.bundleIdentifier,
            snapshotDate: Date()
        )
    }

    /// Static progress based on snapshot — useful when the player is paused.
    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, elapsed / duration))
    }

    /// Interpolated elapsed time at the given clock time.
    func liveElapsed(at now: Date) -> Double {
        guard isPlaying else { return elapsed }
        return min(duration > 0 ? duration : .infinity, elapsed + now.timeIntervalSince(snapshotDate))
    }

    func liveProgress(at now: Date) -> Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, liveElapsed(at: now) / duration))
    }
}
