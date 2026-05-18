import AppKit
import SwiftUI

@MainActor
final class NotchWindowController {

    private var panel: NSPanel?
    private var hostingView: FirstMouseHostingView<AnyView>?
    private let rootView: () -> AnyView

    /// Small invisible always-on panel sitting only over the notch hardware
    /// area. Permanently receives mouse events so drag-and-drop fires even
    /// when the main panel has `ignoresMouseEvents = true` for click-through.
    /// When a drag enters, calls `onDragEnter` so AppDelegate can expand the
    /// main panel into `.drop` state.
    private var dragTargetPanel: NSPanel?

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
            // Start fully click-through (idle state). AppDelegate toggles via
            // setIgnoresMouseEvents based on the state machine. Drag-and-drop
            // is handled by a SEPARATE small dragTargetPanel that always
            // receives mouse events — see installDragTarget(handler:).
            p.ignoresMouseEvents = true
            p.isMovable = false
            p.isReleasedWhenClosed = false
            let host = FirstMouseHostingView(rootView: rootView())
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

    /// Toggle whether the main panel intercepts mouse events. When idle/hint
    /// (`ignore = true`), all clicks pass through to the underlying app —
    /// drag-and-drop is handled separately by the always-on `dragTargetPanel`.
    /// When expanded (`ignore = false`), SwiftUI receives clicks normally.
    func setIgnoresMouseEvents(_ ignore: Bool) {
        panel?.ignoresMouseEvents = ignore
        if !ignore {
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

    /// Install / move the small invisible drag-target panel to sit on top of
    /// the hardware notch area. Always receives mouse events so it can detect
    /// dragged files even while the main panel is fully click-through.
    func installDragTarget(handler: any NSDraggingDestination) {
        guard let screen = ScreenGeometry.notchedScreen(),
              let hot = ScreenGeometry.hotZone(
                safeAreaTop: screen.safeAreaInsets.top,
                screenFrame: screen.frame
              )
        else { return }
        let local = CGRect(
            x: hot.minX - 12,
            y: 0,
            width: hot.width + 24,
            height: hot.height + 8
        )
        let frame = convertToScreenCoordinates(localRect: local, screen: screen)
        if dragTargetPanel == nil {
            let p = NSPanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered, defer: false
            )
            p.level = .statusBar
            p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = false
            p.ignoresMouseEvents = false
            p.isMovable = false
            p.isReleasedWhenClosed = false
            let receiver = DragReceiverView(frame: NSRect(origin: .zero, size: frame.size), destination: handler)
            receiver.autoresizingMask = [.width, .height]
            p.contentView = receiver
            dragTargetPanel = p
        } else {
            dragTargetPanel?.setFrame(frame, display: true)
        }
        dragTargetPanel?.orderFront(nil)
    }

    /// Fixed-size panel canvas. SwiftUI animates content within. Click-through
    /// is controlled by `ignoresMouseEvents`, and drag detection is handled
    /// by a separate small `dragTargetPanel`.
    private func expandedFrame(hot: CGRect) -> CGRect {
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

/// Tiny view inside `dragTargetPanel`. Forwards drag-and-drop callbacks to
/// the AppDelegate's DragSession. Mouse clicks are also forwarded as a
/// no-op via `hitTest` returning nil so the underlying app keeps getting
/// clicks on the notch area (it's hardware-blocked anyway, but Notchy's
/// hot-zone monitor still fires for clicks just outside).
private final class DragReceiverView: NSView {
    private weak var destination: AnyObject?

    init(frame: NSRect, destination: any NSDraggingDestination) {
        self.destination = destination as AnyObject
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let dest = destination as? any NSDraggingDestination else { return .copy }
        return dest.draggingEntered?(sender) ?? .copy
    }
    override func draggingExited(_ sender: NSDraggingInfo?) {
        (destination as? any NSDraggingDestination)?.draggingExited?(sender)
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let dest = destination as? any NSDraggingDestination else { return false }
        return dest.performDragOperation?(sender) ?? false
    }
}

/// Borderless NSPanel subclass that allows becoming key so SwiftUI buttons
/// inside our hosted view actually receive their click events.
private final class ClickableNotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
