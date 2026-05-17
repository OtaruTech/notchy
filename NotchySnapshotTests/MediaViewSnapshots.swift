import Testing
import SwiftUI
import AppKit
import SnapshotTesting
@testable import Notchy

@MainActor
struct MediaViewSnapshots {

    private func host<V: View>(_ view: V, width: CGFloat = 540, height: CGFloat = 180) -> NSView {
        let hosting = NSHostingView(rootView: view)
        hosting.frame = CGRect(x: 0, y: 0, width: width, height: height)
        hosting.layoutSubtreeIfNeeded()
        return hosting
    }

    @Test func standard() {
        let vm = NowPlayingVM(title: "Midnight City", artist: "M83",
                              album: "Hurry Up, We're Dreaming",
                              elapsed: 94, duration: 243, isPlaying: true)
        let view = MediaView(vm: vm)
            .frame(width: 540, height: 180)
            .background(Color.black)
        assertSnapshot(of: host(view), as: .image, named: "standard")
    }

    @Test func longText() {
        let vm = NowPlayingVM(
            title: "A Very Long Song Title That Should Truncate Gracefully Without Breaking Layout",
            artist: "An Artist With A Long Name Too",
            album: "Some Album",
            elapsed: 30, duration: 200, isPlaying: true
        )
        let view = MediaView(vm: vm).frame(width: 540, height: 180).background(Color.black)
        assertSnapshot(of: host(view), as: .image, named: "long-text")
    }

    @Test func paused() {
        let vm = NowPlayingVM(title: "X", artist: "Y", album: "Z",
                              elapsed: 0, duration: 100, isPlaying: false)
        let view = MediaView(vm: vm).frame(width: 540, height: 180).background(Color.black)
        assertSnapshot(of: host(view), as: .image, named: "paused")
    }
}
