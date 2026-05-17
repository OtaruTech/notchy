import AppKit
import SwiftUI

@MainActor
final class NotchWindowController {

    private var panel: NSPanel?
    private let rootView: () -> AnyView

    var contentView: NSView? { panel?.contentView }

    /// `rootView` is a factory so the panel can reattach to a new screen.
    init(@ViewBuilder rootView: @escaping () -> some View) {
        self.rootView = { AnyView(rootView()) }
    }

    func show() {
        let screen = ScreenGeometry.notchedScreen()
        guard let screen,
              let hot = ScreenGeometry.hotZone(
                safeAreaTop: screen.safeAreaInsets.top,
                screenFrame: screen.frame
              )
        else { return }

        let frame = convertToScreenCoordinates(localRect: expandedFrame(hot: hot), screen: screen)

        if panel == nil {
            let p = ClickableNotchPanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            p.level = .statusBar
            p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = false
            // Start opaque-to-events false; AppDelegate toggles based on state.
            // Initial state is .idle so set true here.
            p.ignoresMouseEvents = true
            p.isMovable = false
            p.isReleasedWhenClosed = false
            p.contentView = FirstMouseHostingView(rootView: rootView())
            panel = p
        } else {
            panel?.setFrame(frame, display: true)
        }

        panel?.orderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    /// Toggle whether the panel intercepts mouse events. When idle the panel
    /// should let clicks pass through to the desktop / menu-bar; when expanded
    /// it needs to receive button clicks, scrubber drags, etc.
    func setIgnoresMouseEvents(_ ignore: Bool) {
        panel?.ignoresMouseEvents = ignore
        if !ignore {
            // Become key so SwiftUI buttons fire on click.
            panel?.makeKeyAndOrderFront(nil)
        }
    }

    /// Expanded panel area is wider/taller than the notch — we always allocate the
    /// max expansion box so SwiftUI can animate within it.
    private func expandedFrame(hot: CGRect) -> CGRect {
        let expandedWidth: CGFloat = 540
        let expandedHeight: CGFloat = 220
        let x = hot.midX - expandedWidth / 2
        return CGRect(x: x, y: 0, width: expandedWidth, height: expandedHeight)
    }

    /// NSScreen coords have origin at bottom-left; ScreenGeometry uses top-left.
    private func convertToScreenCoordinates(localRect: CGRect, screen: NSScreen) -> CGRect {
        let originX = screen.frame.minX + localRect.minX
        let originY = screen.frame.maxY - localRect.maxY
        return CGRect(x: originX, y: originY, width: localRect.width, height: localRect.height)
    }
}

/// NSHostingView subclass that forwards the very first click to its subviews
/// without requiring the window to be the key window. Without this, SwiftUI
/// `Button` taps inside a `nonactivatingPanel` are silently swallowed —
/// `acceptsFirstMouse` must explicitly opt in.
private final class FirstMouseHostingView<C: View>: NSHostingView<C> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Borderless NSPanel subclass that allows becoming key so SwiftUI buttons
/// inside our hosted view actually receive their click events.
private final class ClickableNotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            let path = "/tmp/notchy.log"
            let line = "\(Date()) [Notchy.Panel] leftMouseDown at locationInWindow=\(event.locationInWindow) ignoresMouseEvents=\(ignoresMouseEvents) isKey=\(isKeyWindow)\n"
            if let d = line.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: path),
                   let h = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
                    h.seekToEndOfFile(); try? h.write(contentsOf: d); try? h.close()
                } else { try? d.write(to: URL(fileURLWithPath: path)) }
            }
        }
        super.sendEvent(event)
    }
}
