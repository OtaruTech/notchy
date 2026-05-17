import Foundation
import Observation

struct BTDeviceVM: Equatable, Sendable {
    let name: String
    let model: String
    let battery: BatteryReading
}

@MainActor
@Observable
final class BTFeature {
    private(set) var connected: BTDeviceVM?
    private let bridge: IOBluetoothBridge
    private weak var stateMachine: NotchStateMachine?
    private var streamTask: Task<Void, Never>?

    init(bridge: IOBluetoothBridge, stateMachine: NotchStateMachine) {
        self.bridge = bridge
        self.stateMachine = stateMachine
    }

    func start() {
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            guard let self else { return }
            for await event in await bridge.connectionEvents() {
                switch event {
                case .connected(let device):
                    let battery = await bridge.battery(for: device.address)
                    let vm = BTDeviceVM(name: device.name, model: device.model, battery: battery)
                    await MainActor.run {
                        self.connected = vm
                        self.stateMachine?.send(.airPodsConnected)
                    }
                case .disconnected:
                    await MainActor.run { self.connected = nil }
                }
            }
        }
    }
}
