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

    /// True while media is playing — extends the collapsed hover zone with wings
    /// to cover the live-activity strip (album art + waveform on either side).
    var isLiveActivityVisible: Bool = false

    /// Expanded keep-alive zone width/height (matches NotchWindowController.expandedFrame).
    private let expandedWidth: CGFloat = 540
    private let expandedHeight: CGFloat = 220
    private let liveActivityWingWidth: CGFloat = 70

    var onEnter: () -> Void = {}
    var onExit: () -> Void = {}
    var onEscape: () -> Void = {}
    var onClickOutside: () -> Void = {}
    /// Fired when a horizontal trackpad/scroll gesture happens INSIDE the active zone.
    /// `direction > 0` = swipe right (next), `direction < 0` = swipe left (previous).
    var onHorizontalSwipe: (Int) -> Void = { _ in }

    private var scrollAccumulator: CGFloat = 0
    private let scrollThreshold: CGFloat = 25
    /// True once we've already fired in this gesture; reset on `.began` / `.ended`.
    /// Prevents one physical 2-finger flick (which emits dozens of scrollWheel
    /// events + momentum phase) from triggering next-track multiple times.
    private var swipeFiredThisGesture: Bool = false

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDown, .scrollWheel]
        ) { [weak self] event in
            Task { @MainActor in self?.handle(event: event) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDown, .keyDown, .scrollWheel]
        ) { [weak self] event in
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
        // Collapsed: notch hot zone + 4pt buffer, optionally widened by wings when
        // the live-activity strip is showing (album art + waveform around the notch).
        guard let hot = ScreenGeometry.hotZone(
            safeAreaTop: screen.safeAreaInsets.top,
            screenFrame: screen.frame
        ) else { return nil }
        let extraWidth = isLiveActivityVisible ? 2 * liveActivityWingWidth : 0
        return CGRect(
            x: screen.frame.minX + hot.minX - extraWidth / 2,
            y: screen.frame.maxY - hot.maxY,
            width: hot.width + extraWidth,
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

        if event.type == .scrollWheel {
            guard nowInside else { return }
            // Reset accumulator + fire-flag on the START of a new gesture.
            if event.phase.contains(.began) {
                scrollAccumulator = 0
                swipeFiredThisGesture = false
            }
            // Fully reset when fingers lift OR momentum ends.
            if event.phase.contains(.ended) || event.phase.contains(.cancelled)
                || event.momentumPhase.contains(.ended) {
                scrollAccumulator = 0
                // keep swipeFiredThisGesture true through momentum, reset only
                // when truly done — handled by .began on the next gesture.
            }

            let dx = event.hasPreciseScrollingDeltas ? event.scrollingDeltaX : event.deltaX
            let dy = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.deltaY
            guard abs(dx) > abs(dy) else { return }  // horizontal-only
            scrollAccumulator += dx
            if swipeFiredThisGesture { return }  // already fired for this gesture
            if scrollAccumulator >= scrollThreshold {
                onHorizontalSwipe(1)
                swipeFiredThisGesture = true
            } else if scrollAccumulator <= -scrollThreshold {
                onHorizontalSwipe(-1)
                swipeFiredThisGesture = true
            }
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
            // Read user-configurable hover delay (default 120ms).
            let delayMs = UserDefaults.standard.object(forKey: "notchy.hoverDelayMs") as? Double ?? 120
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int(delayMs)), execute: work)
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
