import Testing
import SwiftUI
import AppKit
import SnapshotTesting
@testable import Notchy

@MainActor
struct MediaViewSnapshots {

    @Test func standard() {
        let vm = NowPlayingVM(title: "Midnight City", artist: "M83",
                              album: "Hurry Up, We're Dreaming",
                              elapsed: 94, duration: 243, isPlaying: true, snapshotDate: Date())
        let view = MediaView(vm: vm)
            .frame(width: 540, height: 180)
            .background(Color.black)
        assertSnapshot(of: snapshotHost(view, width: 540, height: 180), as: .image, named: "standard")
    }

    @Test func longText() {
        let vm = NowPlayingVM(
            title: "A Very Long Song Title That Should Truncate Gracefully Without Breaking Layout",
            artist: "An Artist With A Long Name Too",
            album: "Some Album",
            elapsed: 30, duration: 200, isPlaying: true,
            snapshotDate: Date()
        )
        let view = MediaView(vm: vm).frame(width: 540, height: 180).background(Color.black)
        assertSnapshot(of: snapshotHost(view, width: 540, height: 180), as: .image, named: "long-text")
    }

    @Test func paused() {
        let vm = NowPlayingVM(title: "X", artist: "Y", album: "Z",
                              elapsed: 0, duration: 100, isPlaying: false, snapshotDate: Date())
        let view = MediaView(vm: vm).frame(width: 540, height: 180).background(Color.black)
        assertSnapshot(of: snapshotHost(view, width: 540, height: 180), as: .image, named: "paused")
    }
}
