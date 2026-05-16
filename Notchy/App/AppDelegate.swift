import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    let stateMachine = NotchStateMachine()
    private var windowController: NotchWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let sm = stateMachine
        windowController = NotchWindowController {
            NotchShell(stateMachine: sm)
        }
        windowController?.show()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.windowController?.show() }
        }
    }
}
