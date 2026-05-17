import Testing
import Foundation
@testable import Notchy

struct MediaRemoteBridgeTests {

    @Test func parsesFullMediaControlPayload() {
        let payload: [String: Any] = [
            "title": "Midnight City",
            "artist": "M83",
            "album": "Hurry Up, We're Dreaming",
            "elapsedTime": 94.0,
            "duration": 243.0,
            "playing": true
        ]
        let parsed = MediaRemoteBridge.parse(payload: payload)
        #expect(parsed?.title == "Midnight City")
        #expect(parsed?.artist == "M83")
        #expect(parsed?.album == "Hurry Up, We're Dreaming")
        #expect(parsed?.elapsed == 94.0)
        #expect(parsed?.duration == 243.0)
        #expect(parsed?.isPlaying == true)
    }

    @Test func emptyTitleMeansNothingPlaying() {
        #expect(MediaRemoteBridge.parse(payload: [:]) == nil)
        #expect(MediaRemoteBridge.parse(payload: ["title": ""]) == nil)
    }

    @Test func paused() {
        let payload: [String: Any] = ["title": "X", "playing": false]
        #expect(MediaRemoteBridge.parse(payload: payload)?.isPlaying == false)
    }

    @Test func emptyAlbumBecomesNil() {
        let payload: [String: Any] = ["title": "T", "album": "", "playing": true]
        #expect(MediaRemoteBridge.parse(payload: payload)?.album == nil)
    }

    @Test func parsesStreamEnvelope() {
        let json = """
        {"type":"data","diff":false,"payload":{"title":"Stream Title","artist":"X","duration":100,"playing":true}}
        """.data(using: .utf8)!
        let parsed = MediaRemoteBridge.parse(jsonData: json)
        #expect(parsed?.title == "Stream Title")
        #expect(parsed?.artist == "X")
    }

    @Test func parsesRawPayloadJson() {
        let json = """
        {"title":"Direct","artist":"A","duration":50,"elapsedTime":12.5,"playing":true}
        """.data(using: .utf8)!
        let parsed = MediaRemoteBridge.parse(jsonData: json)
        #expect(parsed?.title == "Direct")
        #expect(parsed?.elapsed == 12.5)
    }

    @Test func playbackRateFallback() {
        // Some streams may not include `playing` but have `playbackRate` instead.
        let payload: [String: Any] = ["title": "T", "playbackRate": 1.5]
        #expect(MediaRemoteBridge.parse(payload: payload)?.isPlaying == true)
        let paused: [String: Any] = ["title": "T", "playbackRate": 0.0]
        #expect(MediaRemoteBridge.parse(payload: paused)?.isPlaying == false)
    }
}
