import AppKit
import SwiftUI

@MainActor
final class NotchWindowController {

    private var panel: NSPanel?
    private var hostingView: FirstMouseHostingView<AnyView>?
    private let rootView: () -> AnyView

    var contentView: NSView? { panel?.contentView }

    /// Closure used by the hosting view's `hitTest` override. Returns the rect
    /// (in hosting-view coords) inside which clicks should be claimed.
    /// Defence-in-depth on top of the dynamic panel resize.
    var activeClickRectProvider: (() -> CGRect)? {
        didSet { hostingView?.activeRectProvider = activeClickRectProvider }
    }

    /// Size of the maximum possible panel. We allocate the panel at this
    /// size on first show, then `setFrame(_:display:animate:)` shrinks it on
    /// every state change so the panel only physically covers the currently
    /// visible area. Anything outside is genuinely click-through.
    private static let maxSize = CGSize(width: 920, height: 320)

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
    /// clicks fire.
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

    /// Resize the panel to match the currently-visible area so the surrounding
    /// pixels are genuinely click-through (not just hit-test-nil). Called on
    /// every state change.
    func resize(toLocalSize size: CGSize, animated: Bool) {
        guard let panel,
              let screen = ScreenGeometry.notchedScreen(),
              let hot = ScreenGeometry.hotZone(
                safeAreaTop: screen.safeAreaInsets.top,
                screenFrame: screen.frame
              )
        else { return }
        let clamped = CGSize(
            width: min(size.width, Self.maxSize.width),
            height: min(size.height, Self.maxSize.height)
        )
        let local = CGRect(
            x: hot.midX - clamped.width / 2,
            y: 0,
            width: clamped.width,
            height: clamped.height
        )
        let frame = convertToScreenCoordinates(localRect: local, screen: screen)
        panel.setFrame(frame, display: true, animate: animated)
    }

    /// Initial allocation — uses the maximum possible size so SwiftUI can
    /// animate within it. `resize(toLocalSize:animated:)` shrinks it as soon
    /// as the first state change comes through.
    private func expandedFrame(hot: CGRect) -> CGRect {
        let x = hot.midX - Self.maxSize.width / 2
        return CGRect(x: x, y: 0, width: Self.maxSize.width, height: Self.maxSize.height)
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
