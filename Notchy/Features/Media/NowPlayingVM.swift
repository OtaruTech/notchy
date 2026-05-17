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

    static func from(_ info: NowPlayingInfo) -> NowPlayingVM {
        NowPlayingVM(
            title: info.title,
            artist: info.artist ?? "",
            album: info.album ?? "",
            elapsed: info.elapsed ?? 0,
            duration: info.duration ?? 0,
            isPlaying: info.isPlaying,
            artworkData: info.artworkData,
            sourceBundleId: info.bundleIdentifier
        )
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, elapsed / duration))
    }
}
