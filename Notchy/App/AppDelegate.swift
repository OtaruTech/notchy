import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    let stateMachine = NotchStateMachine()
    private var windowController: NotchWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let sm = stateMachine
        windowController = NotchWindowController {
            NotchPlaceholderView(stateMachine: sm)
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

/// Bare visualization used until NotchShell exists.
struct NotchPlaceholderView: View {
    let stateMachine: NotchStateMachine
    var body: some View {
        VStack {
            Color.black
                .frame(width: 210, height: 32)
                .clipShape(.rect(bottomLeadingRadius: 18, bottomTrailingRadius: 18))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
