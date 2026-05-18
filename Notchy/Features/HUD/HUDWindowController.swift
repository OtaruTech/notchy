import AppKit
import SwiftUI

/// Dedicated transparent NSPanel that hosts only the HUD pill. Sits ABOVE
/// the main notch panel + everything else. Always click-through. Only visible
/// while `HUDFeature.current` is non-nil.
///
/// Architecture choice: keeping the HUD in its own panel side-steps the
/// frame-sizing dance inside the main NotchExpandedView. The main panel
/// can stay clipped to its small notch-shaped area while the HUD draws
/// freely in the centre of the screen just below the notch.
@MainActor
final class HUDWindowController {

    private var panel: NSPanel?
    private var hostingView: NSHostingView<HUDPanelRoot>?

    private let feature: HUDFeature

    init(feature: HUDFeature) {
        self.feature = feature
    }

    func show() {
        guard let screen = ScreenGeometry.notchedScreen(),
              let hot = ScreenGeometry.hotZone(
                safeAreaTop: screen.safeAreaInsets.top,
                screenFrame: screen.frame
              )
        else { return }
        let notchH = ScreenGeometry.liveNotchHeight()
        let panelWidth: CGFloat = 400
        let panelHeight: CGFloat = notchH + 70
        // Centre the panel on the actual notch hot-zone midpoint (not the
        // screen midpoint — multi-monitor + tall menubar can offset things).
        // hot is in top-left coords; convert to NSScreen bottom-left coords.
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
            // Above main notch panel (statusBar) so HUD draws on top.
            p.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
            p.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = false
            p.ignoresMouseEvents = true  // HUD is display-only
            p.isReleasedWhenClosed = false

            let root = HUDPanelRoot(feature: feature, topPadding: notchH + 6)
            let host = NSHostingView(rootView: root)
            host.frame = NSRect(origin: .zero, size: frame.size)
            host.autoresizingMask = [.width, .height]
            p.contentView = host
            panel = p
            hostingView = host
        } else {
            panel?.setFrame(frame, display: true)
        }
        panel?.orderFront(nil)
    }
}

/// Bindable root for the HUD panel — re-renders whenever HUDFeature.current
/// changes.
struct HUDPanelRoot: View {
    @Bindable var feature: HUDFeature
    let topPadding: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            if let event = feature.current {
                HUDView(event: event)
                    .padding(.top, topPadding)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.easeOut(duration: 0.22), value: feature.current)
    }
}
