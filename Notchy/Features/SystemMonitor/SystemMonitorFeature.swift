import Foundation
import Observation

@MainActor
@Observable
final class SystemMonitorFeature {
    private(set) var snapshot: SystemSnapshot = SystemSnapshot(cpuPercent: 0, batteryPercent: nil, isCharging: false)
    private let bridge: SystemMonitorBridge
    private var pollTask: Task<Void, Never>?

    init(bridge: SystemMonitorBridge) {
        self.bridge = bridge
    }

    func start() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let snap = await bridge.snapshot()
                await MainActor.run { self.snapshot = snap }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }
}
