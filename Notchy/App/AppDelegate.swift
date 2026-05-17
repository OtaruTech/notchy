import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    let stateMachine = NotchStateMachine()
    let mediaBridge = MediaRemoteBridge()
    private(set) var mediaFeature: MediaFeature!
    private var windowController: NotchWindowController?
    private var hotZone: HotZoneMonitor?
    let dropFeature = DropFeature()
    private var dragSession: DragSession?
    private var airpodsDismissTimer: Task<Void, Never>?
    private var dropDismissTimer: Task<Void, Never>?
    let btBridge = IOBluetoothBridge()
    private(set) var btFeature: BTFeature!
    private var stateObservation: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        mediaFeature = MediaFeature(bridge: mediaBridge, stateMachine: stateMachine)
        mediaFeature.start()

        btFeature = BTFeature(bridge: btBridge, stateMachine: stateMachine)
        btFeature.start()

        let sm = stateMachine
        let mf = mediaFeature!
        let df = dropFeature
        let bf = btFeature!
        windowController = NotchWindowController { [weak self] in
            NotchShell(
                stateMachine: sm,
                mediaFeature: mf,
                dropFeature: df,
                onAirDrop: { self?.performAirDrop() },
                onEmail: { self?.performEmail() },
                btFeature: bf
            )
        }
        windowController?.show()

        let monitor = HotZoneMonitor()
        monitor.onEnter = { [weak self] in self?.stateMachine.send(.hoverEntered) }
        monitor.onExit = { [weak self] in self?.stateMachine.send(.hoverExited) }
        monitor.onEscape = { [weak self] in self?.stateMachine.send(.escapeKeyPressed) }
        monitor.onClickOutside = { [weak self] in self?.stateMachine.send(.outsideClicked) }
        monitor.start()
        hotZone = monitor

        let drag = DragSession()
        drag.onEnter = { [weak self] in
            self?.stateMachine.send(.dragEntered)
            self?.dropDismissTimer?.cancel()
        }
        drag.onExit = { [weak self] in
            self?.scheduleDropDismiss()
        }
        drag.onDrop = { [weak self] urls in
            self?.dropFeature.add(urls: urls)
            self?.scheduleDropDismiss()
        }
        if let cv = windowController?.contentView {
            drag.attach(to: cv)
        }
        dragSession = drag

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.windowController?.show() }
        }

        stateObservation = Task { [weak self] in
            var last: NotchState = .idle
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self else { return }
                let s = await MainActor.run { self.stateMachine.state }
                if s == .airpods, last != .airpods {
                    self.airpodsDismissTimer?.cancel()
                    self.airpodsDismissTimer = Task { [weak self] in
                        try? await Task.sleep(for: DesignTokens.airPodsDismissDelay)
                        await MainActor.run { self?.stateMachine.send(.dismissTimerFired) }
                    }
                }
                last = s
            }
        }
    }

    private func scheduleDropDismiss() {
        dropDismissTimer?.cancel()
        dropDismissTimer = Task { [weak self] in
            try? await Task.sleep(for: DesignTokens.dragDismissDelay)
            await MainActor.run { self?.stateMachine.send(.dragExited) }
        }
    }

    @MainActor
    func performAirDrop() {
        let urls = dropFeature.items.map(\.url)
        guard !urls.isEmpty else { return }
        let sharing = NSSharingService(named: .sendViaAirDrop)
        sharing?.perform(withItems: urls)
    }

    @MainActor
    func performEmail() {
        let urls = dropFeature.items.map(\.url)
        guard !urls.isEmpty else { return }
        let service = NSSharingService(named: .composeEmail)
        service?.perform(withItems: urls)
    }
}
