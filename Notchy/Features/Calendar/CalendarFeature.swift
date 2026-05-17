import Foundation
import Observation

@MainActor
@Observable
final class CalendarFeature {
    private(set) var events: [EventVM] = []
    private(set) var permissionState: EventKitBridge.AccessResult = .denied
    private let bridge: EventKitBridge
    private weak var stateMachine: NotchStateMachine?
    private var refreshTimer: Task<Void, Never>?

    init(bridge: EventKitBridge, stateMachine: NotchStateMachine) {
        self.bridge = bridge
        self.stateMachine = stateMachine
    }

    func start() async {
        permissionState = await bridge.requestAccess()
        guard permissionState == .granted else { return }
        await refresh()
        scheduleRefresh()
    }

    private func refresh() async {
        let vms = await bridge.todaysEvents()
        events = vms
        stateMachine?.send(.calendarAvailabilityChanged(!vms.isEmpty))
    }

    private func scheduleRefresh() {
        refreshTimer?.cancel()
        refreshTimer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                await self?.refresh()
            }
        }
    }

    func stop() {
        refreshTimer?.cancel()
        refreshTimer = nil
    }
}
