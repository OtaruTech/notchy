import AppKit
import SwiftUI

/// Dedicated NSPanel that hosts the notification pill. Sits at statusBar+1
/// level (same as HUD) but receives mouse events so the user can click to
/// focus the source terminal / dismiss.
///
/// Repositioned on every `show()` to handle multi-display setups + display
/// reconfiguration.
@MainActor
final class NotificationWindowController {

    private var panel: NSPanel?
    private let feature: NotificationFeature

    init(feature: NotificationFeature) {
        self.feature = feature
    }

    func show() {
        guard let screen = ScreenGeometry.notchedScreen() ?? NSScreen.main,
              let hot = ScreenGeometry.hotZone(
                safeAreaTop: screen.safeAreaInsets.top,
                screenFrame: screen.frame
              )
        else { return }

        let notchH = ScreenGeometry.liveNotchHeight()
        let panelWidth: CGFloat = 420
        let panelHeight: CGFloat = notchH + 110

        // Centre under the notch hot-zone (NOT the screen midpoint — multi-
        // display setups have offset midpoints).
        let frame = CGRect(
            x: screen.frame.minX + hot.midX - panelWidth / 2,
            y: screen.frame.maxY - panelHeight,
            width: panelWidth,
            height: panelHeight
        )

        if panel == nil {
            let p = NSPanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered, defer: false
            )
            p.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
            p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = false
            // Mouse events ENABLED — user clicks the pill to focus terminal.
            // The empty space around the pill stays click-through via the
            // root view's hit-testing (pill itself draws the only opaque area).
            p.ignoresMouseEvents = false
            p.becomesKeyOnlyIfNeeded = true
            p.isReleasedWhenClosed = false

            let root = NotificationPanelRoot(feature: feature, topPadding: notchH + 8)
            let host = NSHostingView(rootView: root)
            host.frame = NSRect(origin: .zero, size: frame.size)
            host.autoresizingMask = [.width, .height]
            p.contentView = host
            panel = p
        } else {
            panel?.setFrame(frame, display: true)
        }
        panel?.orderFront(nil)
    }
}

/// Root view that anchors the pill at the top of the panel, leaving the rest
/// transparent and click-through. Re-renders whenever `feature.current`
/// changes.
struct NotificationPanelRoot: View {
    @Bindable var feature: NotificationFeature
    let topPadding: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            if let note = feature.current {
                NotificationPillView(note: note) {
                    feature.clickCurrent()
                }
                .padding(.top, topPadding)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.4, dampingFraction: 0.78), value: feature.current?.id)
        // Block hit-testing outside the pill so the rest of the panel stays
        // click-through. The pill itself is a SwiftUI Button so it consumes
        // its own clicks.
        .allowsHitTesting(feature.current != nil)
    }
}
