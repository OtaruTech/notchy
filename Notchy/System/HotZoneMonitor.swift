import AppKit

@MainActor
final class HotZoneMonitor {

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var hoverWorkItem: DispatchWorkItem?
    private var leaveWorkItem: DispatchWorkItem?
    private var isInside = false

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

    private func handle(event: NSEvent) {
        if event.type == .keyDown, event.keyCode == 53 /* Esc */ {
            onEscape()
            return
        }

        let mouseLocation = NSEvent.mouseLocation
        guard let screen = ScreenGeometry.notchedScreen(),
              let hot = ScreenGeometry.hotZone(
                safeAreaTop: screen.safeAreaInsets.top,
                screenFrame: screen.frame
              )
        else { return }

        // Convert hot zone (top-left origin) to screen coords (bottom-left origin).
        let hotInScreenCoords = CGRect(
            x: screen.frame.minX + hot.minX,
            y: screen.frame.maxY - hot.maxY,
            width: hot.width,
            height: hot.height
        )

        let nowInside = hotInScreenCoords.contains(mouseLocation)

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
