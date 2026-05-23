import AppKit
import SwiftUI
import Observation

/// Dedicated NSPanel that hosts the notification pill. Sits at statusBar+1
/// level (same as HUD).
///
/// ## Click-through behaviour
///
/// **The panel must NOT consume mouse events when no notification is visible.**
/// Otherwise the panel's frame (420 × ~148 pt under the notch) silently swallows
/// every click in that region, even though SwiftUI is drawing nothing — apps
/// behind the panel become un-interactive. We hit this once and lost an afternoon
/// to it; the regression test `NotificationWindowControllerClickThroughTests`
/// catches a re-occurrence.
///
/// Implementation: `panel.ignoresMouseEvents` is **bound** to `feature.current`
/// via `withObservationTracking`. When `feature.current == nil` the panel is
/// transparent to events; when a pill is showing it captures clicks so the user
/// can dismiss / focus the source terminal. The SwiftUI-level
/// `.allowsHitTesting` on the root view is NOT sufficient — AppKit's window-
/// level hit testing claims the event for the panel's NSWindow before SwiftUI
/// gets to decide.
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
            p.becomesKeyOnlyIfNeeded = true
            p.isReleasedWhenClosed = false

            // Default: click-through. Toggled to false only while a pill is up.
            p.ignoresMouseEvents = true

            let root = NotificationPanelRoot(feature: feature, topPadding: notchH + 8)
            let host = NSHostingView(rootView: root)
            host.frame = NSRect(origin: .zero, size: frame.size)
            host.autoresizingMask = [.width, .height]
            p.contentView = host
            panel = p

            startObserving()
        } else {
            panel?.setFrame(frame, display: true)
        }
        panel?.orderFront(nil)
    }

    /// Observe `feature.current` and keep `panel.ignoresMouseEvents` inverted
    /// to its non-nil-ness. Re-arms itself on every change — that's how
    /// `withObservationTracking` works with the `@Observable` macro.
    ///
    /// Exposed `internal` for the unit test to drive deterministically.
    func startObserving() {
        applyMouseGate()
        withObservationTracking { [weak self] in
            // Read the property INSIDE the tracking block so the dependency
            // is registered. Storing it nowhere is fine.
            _ = self?.feature.current
        } onChange: { [weak self] in
            // onChange fires once per change, on the calling actor's queue.
            Task { @MainActor [weak self] in
                self?.applyMouseGate()
                self?.startObserving()      // re-arm
            }
        }
    }

    /// Single source of truth for the mouse-event gate. Exposed `internal` so
    /// the unit test can force-recompute after pushing a notification without
    /// having to drive the observation runtime.
    func applyMouseGate() {
        let showing = feature.current != nil
        panel?.ignoresMouseEvents = !showing
    }

    /// `true` ⇒ the panel passes mouse events through to apps below.
    /// `false` ⇒ the pill is up and the panel is capturing clicks.
    /// Backed by `NSPanel.ignoresMouseEvents`. The regression test
    /// `NotificationWindowControllerClickThroughTests` asserts this returns
    /// `true` when there is no current notification (the bug we fixed).
    var isClickThrough: Bool {
        panel?.ignoresMouseEvents ?? true
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
    }
}
