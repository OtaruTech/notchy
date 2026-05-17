import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    let stateMachine = NotchStateMachine()
    let mediaBridge = MediaRemoteBridge()
    private(set) var mediaFeature: MediaFeature!
    private var windowController: NotchWindowController?
    private var hotZone: HotZoneMonitor?
    let dropFeature = DropFeature()
    private var dragSession: DragSession?
    private var airpodsDismissTimer: Task<Void, Never>?
    private var dropDismissTimer: Task<Void, Never>?
    let btBridge = IOBluetoothBridge()
    private(set) var btFeature: BTFeature!
    let eventBridge = EventKitBridge()
    let monitorBridge = SystemMonitorBridge()
    private(set) var calendarFeature: CalendarFeature!
    private(set) var timerFeature: TimerFeature!
    private(set) var systemMonitor: SystemMonitorFeature!
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?

    nonisolated(unsafe) private static var weakSelf: AppDelegate?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.weakSelf = self
        installSignalHandlers()
        promptAccessibilityIfNeeded()

        mediaFeature = MediaFeature(bridge: mediaBridge, stateMachine: stateMachine)
        mediaFeature.start()

        btFeature = BTFeature(bridge: btBridge, stateMachine: stateMachine)
        btFeature.start()

        calendarFeature = CalendarFeature(bridge: eventBridge, stateMachine: stateMachine)
        Task { await calendarFeature.start() }

        timerFeature = TimerFeature(stateMachine: stateMachine)

        systemMonitor = SystemMonitorFeature(bridge: monitorBridge)
        systemMonitor.start()

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "🌒"
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        let timerMenu = NSMenu()
        timerMenu.addItem(NSMenuItem(title: "25 minutes", action: #selector(startTimer25), keyEquivalent: ""))
        timerMenu.addItem(NSMenuItem(title: "15 minutes", action: #selector(startTimer15), keyEquivalent: ""))
        timerMenu.addItem(NSMenuItem(title: "5 minutes", action: #selector(startTimer5), keyEquivalent: ""))
        let timerItem = NSMenuItem(title: "Start Timer", action: nil, keyEquivalent: "")
        timerItem.submenu = timerMenu
        menu.addItem(timerItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Notchy", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item

        let sm = stateMachine
        let mf = mediaFeature!
        let df = dropFeature
        let bf = btFeature!
        let cf = calendarFeature!
        let tf = timerFeature!
        let smon = systemMonitor!
        windowController = NotchWindowController { [weak self] in
            NotchShell(
                stateMachine: sm,
                mediaFeature: mf,
                dropFeature: df,
                onAirDrop: { self?.performAirDrop() },
                onEmail: { self?.performEmail() },
                btFeature: bf,
                calendarFeature: cf,
                timerFeature: tf,
                systemMonitor: smon
            )
        }
        windowController?.show()

        let monitor = HotZoneMonitor()
        monitor.onEnter = { [weak self] in self?.stateMachine.send(.hoverEntered) }
        monitor.onExit = { [weak self] in self?.stateMachine.send(.hoverExited) }
        monitor.onEscape = { [weak self] in self?.stateMachine.send(.escapeKeyPressed) }
        monitor.onClickOutside = { [weak self] in self?.stateMachine.send(.outsideClicked) }
        monitor.start()
        hotZone = monitor

        let drag = DragSession()
        drag.onEnter = { [weak self] in
            self?.stateMachine.send(.dragEntered)
            self?.dropDismissTimer?.cancel()
        }
        drag.onExit = { [weak self] in
            self?.scheduleDropDismiss()
        }
        drag.onDrop = { [weak self] urls in
            self?.dropFeature.add(urls: urls)
            self?.scheduleDropDismiss()
        }
        if let cv = windowController?.contentView {
            drag.attach(to: cv)
        }
        dragSession = drag

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.windowController?.show()
                if let cv = self.windowController?.contentView, let drag = self.dragSession {
                    drag.attach(to: cv)
                }
            }
        }

        observeStateChanges()
    }

    private func observeStateChanges() {
        withObservationTracking {
            _ = stateMachine.state
        } onChange: {
            Task { @MainActor [weak self] in
                self?.handleStateChange()
                self?.observeStateChanges()  // re-subscribe (one-shot)
            }
        }
    }

    private func handleStateChange() {
        // Toggle click-through: idle/hint = transparent area must pass clicks
        // through to the desktop; expanded states need to receive clicks.
        windowController?.setIgnoresMouseEvents(!stateMachine.state.isExpanded)

        if stateMachine.state == .airpods {
            airpodsDismissTimer?.cancel()
            airpodsDismissTimer = Task { [weak self] in
                try? await Task.sleep(for: DesignTokens.airPodsDismissDelay)
                await MainActor.run { self?.stateMachine.send(.dismissTimerFired) }
            }
        }
    }

    private func scheduleDropDismiss() {
        dropDismissTimer?.cancel()
        dropDismissTimer = Task { [weak self] in
            try? await Task.sleep(for: DesignTokens.dragDismissDelay)
            await MainActor.run { self?.stateMachine.send(.dragExited) }
        }
    }

    @MainActor
    func performAirDrop() {
        let urls = dropFeature.items.map(\.url)
        guard !urls.isEmpty else { return }
        let sharing = NSSharingService(named: .sendViaAirDrop)
        sharing?.perform(withItems: urls)
    }

    @MainActor
    func performEmail() {
        let urls = dropFeature.items.map(\.url)
        guard !urls.isEmpty else { return }
        let service = NSSharingService(named: .composeEmail)
        service?.perform(withItems: urls)
    }

    @objc func openSettings() {
        // LSUIElement (accessory) apps can't reliably show SwiftUI's Settings scene.
        // Promote to regular activation, host SettingsView in an NSWindow, revert on close.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "Notchy Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 420, height: 320))
            window.isReleasedWhenClosed = false
            window.center()
            window.delegate = self
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc func startTimer25() { timerFeature.start(seconds: 1500) }
    @objc func startTimer15() { timerFeature.start(seconds: 900) }
    @objc func startTimer5() { timerFeature.start(seconds: 300) }

    /// Trigger the system Accessibility prompt so Notchy appears in
    /// System Settings → Privacy & Security → Accessibility. Without this,
    /// NSEvent global monitors silently fail (return nil) and hover never fires.
    private func promptAccessibilityIfNeeded() {
        // Swift 6 doesn't let us touch the bridged kAXTrustedCheckOptionPrompt global
        // (it's an unsafe shared mutable). Use the literal key string instead — the
        // value is stable in macOS history.
        let options = ["AXTrustedCheckOptionPrompt": kCFBooleanTrue!] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func installSignalHandlers() {
        let handler: @convention(c) (Int32) -> Void = { _ in
            Task { @MainActor in
                AppDelegate.weakSelf?.windowController?.hide()
                exit(1)
            }
        }
        signal(SIGTERM, handler)
        signal(SIGABRT, handler)
        signal(SIGSEGV, handler)
    }
}

extension AppDelegate: NSWindowDelegate {
    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            // Settle one runloop tick before reverting activation policy,
            // so AppKit finishes the close transition cleanly.
            try? await Task.sleep(for: .milliseconds(100))
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
