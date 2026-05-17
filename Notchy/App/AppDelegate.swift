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

    func applicationDidFinishLaunching(_ notification: Notification) {
        mediaFeature = MediaFeature(bridge: mediaBridge, stateMachine: stateMachine)
        mediaFeature.start()

        let sm = stateMachine
        let mf = mediaFeature!
        windowController = NotchWindowController {
            NotchShell(stateMachine: sm, mediaFeature: mf)
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
    }

    private func scheduleDropDismiss() {
        dropDismissTimer?.cancel()
        dropDismissTimer = Task { [weak self] in
            try? await Task.sleep(for: DesignTokens.dragDismissDelay)
            await MainActor.run { self?.stateMachine.send(.dragExited) }
        }
    }
}
