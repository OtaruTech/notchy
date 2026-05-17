import AppKit
import SwiftUI

/// Tiny AppKit overlay that reliably fires `onTap` on left-mouse-down, regardless
/// of whether the host window is key. SwiftUI's `.onTapGesture` and `Button` both
/// silently fail inside a `nonactivatingPanel` + `NSHostingView`; this is the
/// workaround.
///
/// Use as an invisible ZStack overlay on top of the visual button content:
/// ```swift
/// ZStack {
///     Circle().fill(.white)
///     Image(systemName: "pause.fill")
///     TapCatcher { onPlayPause() }
/// }
/// .frame(width: 42, height: 42)
/// ```
struct TapCatcher: NSViewRepresentable {
    let onTap: () -> Void

    func makeNSView(context: Context) -> TappableNSView {
        let v = TappableNSView()
        v.onTap = onTap
        return v
    }

    func updateNSView(_ nsView: TappableNSView, context: Context) {
        nsView.onTap = onTap
    }
}

final class TappableNSView: NSView {
    var onTap: () -> Void = {}

    /// Fire even when the host window isn't key — critical for nonactivatingPanel.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        // Don't call super — we don't want any default behavior.
        onTap()
    }

    /// We don't want to participate in keyboard focus chain; just clicks.
    override var acceptsFirstResponder: Bool { false }

    /// Make sure we receive hit-tests inside our bounds even though we're empty.
    override func hitTest(_ point: NSPoint) -> NSView? {
        return bounds.contains(point) ? self : nil
    }
}
