import Testing
import Foundation
@testable import Notchy

struct MediaRemoteBridgeTests {

    @Test func parsesFullPayload() {
        let raw: [String: Any] = [
            "kMRMediaRemoteNowPlayingInfoTitle": "Midnight City",
            "kMRMediaRemoteNowPlayingInfoArtist": "M83",
            "kMRMediaRemoteNowPlayingInfoAlbum": "Hurry Up, We're Dreaming",
            "kMRMediaRemoteNowPlayingInfoElapsedTime": 94.0,
            "kMRMediaRemoteNowPlayingInfoDuration": 243.0,
            "kMRMediaRemoteNowPlayingInfoPlaybackRate": 1.0
        ]
        let parsed = MediaRemoteBridge.parse(raw: raw)
        #expect(parsed?.title == "Midnight City")
        #expect(parsed?.artist == "M83")
        #expect(parsed?.album == "Hurry Up, We're Dreaming")
        #expect(parsed?.elapsed == 94.0)
        #expect(parsed?.duration == 243.0)
        #expect(parsed?.isPlaying == true)
    }

    @Test func emptyTitleMeansNothingPlaying() {
        let raw: [String: Any] = [:]
        #expect(MediaRemoteBridge.parse(raw: raw) == nil)
    }

    @Test func paused() {
        let raw: [String: Any] = [
            "kMRMediaRemoteNowPlayingInfoTitle": "X",
            "kMRMediaRemoteNowPlayingInfoPlaybackRate": 0.0
        ]
        #expect(MediaRemoteBridge.parse(raw: raw)?.isPlaying == false)
    }
}
