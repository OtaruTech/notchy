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
            p.contentView = NSHostingView(rootView: rootView())
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

/// Borderless NSPanel subclass that allows becoming key so SwiftUI buttons
/// inside our hosted view actually receive their click events.
/// Default NSPanel.canBecomeKey is false for borderless panels, which silently
/// drops button taps on our Now Playing / Drop tray / Mirror controls.
private final class ClickableNotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
