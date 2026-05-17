import Testing
@testable import Notchy

@MainActor
struct MediaFeatureTests {
    @Test func progressZeroWhenNoDuration() {
        let vm = NowPlayingVM(title: "x", artist: "", album: "", elapsed: 5, duration: 0, isPlaying: true)
        #expect(vm.progress == 0)
    }

    @Test func progressHalfway() {
        let vm = NowPlayingVM(title: "x", artist: "", album: "", elapsed: 5, duration: 10, isPlaying: true)
        #expect(vm.progress == 0.5)
    }

    @Test func fromInfoMapsFields() {
        let info = NowPlayingInfo(title: "T", artist: "A", album: "B", elapsed: 1, duration: 2, isPlaying: true)
        let vm = NowPlayingVM.from(info)
        #expect(vm.title == "T")
        #expect(vm.artist == "A")
        #expect(vm.album == "B")
        #expect(vm.progress == 0.5)
    }
}
