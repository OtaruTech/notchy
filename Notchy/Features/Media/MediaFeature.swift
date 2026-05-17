import Foundation
import Observation

fileprivate func _mfLog(_ msg: String) {
    let line = "\(Date()) [Notchy.MediaFeature] \(msg)\n"
    let path = "/tmp/notchy.log"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: path),
           let h = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
            h.seekToEndOfFile()
            try? h.write(contentsOf: data)
            try? h.close()
        } else {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}

@MainActor
@Observable
final class MediaFeature {

    private(set) var current: NowPlayingVM?
    private let bridge: MediaRemoteBridge
    private weak var stateMachine: NotchStateMachine?
    private var streamTask: Task<Void, Never>?

    init(bridge: MediaRemoteBridge, stateMachine: NotchStateMachine) {
        self.bridge = bridge
        self.stateMachine = stateMachine
    }

    func start() {
        streamTask?.cancel()
        _mfLog("MediaFeature.start() called")
        streamTask = Task { [weak self] in
            guard let self else { return }
            _mfLog("MediaFeature awaiting bridge.changes()…")
            let stream = await bridge.changes()
            _mfLog("MediaFeature got AsyncStream, entering for-await loop")
            for await info in stream {
                let vm = info.map(NowPlayingVM.from(_:))
                _mfLog("MediaFeature received info: title=\(vm?.title ?? "<nil>") playing=\(vm?.isPlaying ?? false)")
                await MainActor.run {
                    self.current = vm
                    let available = vm?.isPlaying == true
                    _mfLog("MediaFeature sending .mediaAvailabilityChanged(\(available))")
                    self.stateMachine?.send(.mediaAvailabilityChanged(available))
                }
            }
            _mfLog("MediaFeature for-await loop EXITED")
        }
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
    }

    func playPause() {
        Task { await bridge.send(.togglePlayPause) }
    }

    func next() {
        Task { await bridge.send(.next) }
    }

    func prev() {
        Task { await bridge.send(.previous) }
    }
}
