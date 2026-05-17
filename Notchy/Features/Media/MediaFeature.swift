import Foundation
import Observation

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
        streamTask = Task { [weak self] in
            guard let self else { return }
            for await info in await bridge.changes() {
                let vm = info.map(NowPlayingVM.from(_:))
                await MainActor.run {
                    self.current = vm
                    self.stateMachine?.send(.mediaAvailabilityChanged(vm?.isPlaying == true))
                }
            }
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
