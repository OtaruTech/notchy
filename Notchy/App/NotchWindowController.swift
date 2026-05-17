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

    /// Explicitly drop key-window status WITHOUT hiding the panel. Used after
    /// a clipboard paste so the synthesised ⌘V lands in the *previous* app
    /// rather than getting eaten by Notchy.
    func resignKey() {
        panel?.resignKey()
        panel?.ignoresMouseEvents = true
    }

    /// Expanded panel area is wider/taller than the notch — we always allocate the
    /// max expansion box so SwiftUI can animate within it.
    private func expandedFrame(hot: CGRect) -> CGRect {
        // Wide enough to host the clipboard panel's horizontal card strip.
        // Other states render centered within and clip to their own width.
        let expandedWidth: CGFloat = 920
        let expandedHeight: CGFloat = 320
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

/// NSHostingView subclass that accepts first-mouse so SwiftUI buttons inside
/// our `nonactivatingPanel` receive their click events without requiring the
/// host window to be the key window.
private final class FirstMouseHostingView<C: View>: NSHostingView<C> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Borderless NSPanel subclass that allows becoming key so SwiftUI buttons
/// inside our hosted view actually receive their click events.
private final class ClickableNotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
