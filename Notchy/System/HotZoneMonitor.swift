import AppKit

@MainActor
final class HotZoneMonitor {

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var hoverWorkItem: DispatchWorkItem?
    private var leaveWorkItem: DispatchWorkItem?
    private var isInside = false

    /// Controlled externally by AppDelegate when the state machine expands/collapses.
    /// When expanded, the keep-alive zone grows to the full panel (540×220) so the
    /// cursor can move down into the expanded content without triggering hoverExited.
    /// When collapsed, the zone is the small notch hot rect only.
    var isExpanded: Bool = false

    /// Expanded keep-alive zone width/height (matches NotchWindowController.expandedFrame).
    private let expandedWidth: CGFloat = 540
    private let expandedHeight: CGFloat = 220

    var onEnter: () -> Void = {}
    var onExit: () -> Void = {}
    var onEscape: () -> Void = {}
    var onClickOutside: () -> Void = {}

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown]) { [weak self] event in
            Task { @MainActor in self?.handle(event: event) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .keyDown]) { [weak self] event in
            Task { @MainActor in self?.handle(event: event) }
            return event
        }
    }

    func stop() {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
        globalMonitor = nil
        localMonitor = nil
    }

    /// Computes the current keep-alive rect in screen (bottom-left-origin) coords.
    private func activeZone(on screen: NSScreen) -> CGRect? {
        if isExpanded {
            // Full panel area covering 540 × 220 below the notch.
            let x = screen.frame.midX - expandedWidth / 2
            // panel sits at top of screen; bottom-edge in NSScreen coords = maxY - height
            let y = screen.frame.maxY - expandedHeight
            return CGRect(x: x, y: y, width: expandedWidth, height: expandedHeight)
        }
        // Collapsed: just the notch hot zone + 4pt buffer.
        guard let hot = ScreenGeometry.hotZone(
            safeAreaTop: screen.safeAreaInsets.top,
            screenFrame: screen.frame
        ) else { return nil }
        return CGRect(
            x: screen.frame.minX + hot.minX,
            y: screen.frame.maxY - hot.maxY,
            width: hot.width,
            height: hot.height
        )
    }

    private func handle(event: NSEvent) {
        if event.type == .keyDown, event.keyCode == 53 /* Esc */ {
            onEscape()
            return
        }

        let mouseLocation = NSEvent.mouseLocation
        guard let screen = ScreenGeometry.notchedScreen(),
              let zone = activeZone(on: screen)
        else { return }

        let nowInside = zone.contains(mouseLocation)

        if event.type == .leftMouseDown {
            if !nowInside { onClickOutside() }
            return
        }

        if nowInside, !isInside {
            isInside = true
            leaveWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.isInside else { return }
                self.onEnter()
            }
            hoverWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(120), execute: work)
        } else if !nowInside, isInside {
            isInside = false
            hoverWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self, !self.isInside else { return }
                self.onExit()
            }
            leaveWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(250), execute: work)
        }
    }
}
