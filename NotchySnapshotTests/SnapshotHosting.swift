import AppKit
import SwiftUI

@MainActor
func snapshotHost<V: View>(_ view: V, width: CGFloat, height: CGFloat) -> NSView {
    let host = NSHostingView(rootView: view)
    host.frame = NSRect(x: 0, y: 0, width: width, height: height)
    host.layoutSubtreeIfNeeded()
    return host
}
