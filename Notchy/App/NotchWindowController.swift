import AppKit
import SwiftUI

@MainActor
final class NotchWindowController {

    private var panel: NSPanel?
    private var hostingView: FirstMouseHostingView<AnyView>?
    private let rootView: () -> AnyView

    var contentView: NSView? { panel?.contentView }

    /// Closure used by the hosting view's `hitTest` override. Returns the rect
    /// (in hosting-view coords) inside which clicks should be claimed. Anything
    /// outside falls through to the desktop. Set by AppDelegate on every state
    /// change so click-through tracks the visible panel size.
    var activeClickRectProvider: (() -> CGRect)? {
        didSet { hostingView?.activeRectProvider = activeClickRectProvider }
    }

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
            // Panel mouse events MUST stay enabled even when collapsed so the
            // drag-and-drop intermediary can detect files dragged over the
            // notch. The SwiftUI content uses `.allowsHitTesting(false)` in
            // collapsed states to let clicks fall through to the desktop, and
            // DragInterceptView's hitTest returns nil to pass clicks to
            // SwiftUI rather than trapping them.
            p.ignoresMouseEvents = false
            p.isMovable = false
            p.isReleasedWhenClosed = false
            let host = FirstMouseHostingView(rootView: rootView())
            host.activeRectProvider = activeClickRectProvider
            p.contentView = host
            hostingView = host
            panel = p
        } else {
            panel?.setFrame(frame, display: true)
        }

        panel?.orderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    /// Bring the panel key when entering an expanded state so SwiftUI button
    /// clicks fire. Click-through in collapsed state is handled by the SwiftUI
    /// `.allowsHitTesting(false)` modifier — we don't toggle ignoresMouseEvents
    /// any more because doing so disables drag-and-drop detection too.
    func setIgnoresMouseEvents(_ ignore: Bool) {
        if !ignore {
            panel?.makeKeyAndOrderFront(nil)
        }
    }

    /// Explicitly drop key-window status WITHOUT hiding the panel. Used after
    /// a clipboard paste so the synthesised ⌘V lands in the *previous* app
    /// rather than getting eaten by Notchy.
    func resignKey() {
        panel?.resignKey()
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

/// NSHostingView subclass that:
/// 1. Accepts first-mouse so SwiftUI buttons inside our `nonactivatingPanel`
///    receive their click events without requiring the host window to be the
///    key window.
/// 2. Overrides `hitTest` to claim clicks ONLY inside the rect returned by
///    `activeRectProvider`. Anywhere outside (the empty area of the 920×320
///    panel canvas when collapsed) returns nil so AppKit treats that point
///    as `ignoresMouseEvents`, letting the underlying app receive the click.
///    Drag-and-drop is unaffected — it routes through NSDraggingDestination
///    independent of hit-testing.
private final class FirstMouseHostingView<C: View>: NSHostingView<C> {
    var activeRectProvider: (() -> CGRect)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if let provider = activeRectProvider {
            let active = provider()
            guard active.contains(point) else { return nil }
        }
        return super.hitTest(point)
    }
}

/// Borderless NSPanel subclass that allows becoming key so SwiftUI buttons
/// inside our hosted view actually receive their click events.
private final class ClickableNotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
