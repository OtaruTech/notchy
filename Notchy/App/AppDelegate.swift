import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    let stateMachine = NotchStateMachine()
    let mediaBridge = MediaRemoteBridge()
    private(set) var mediaFeature: MediaFeature!
    private var windowController: NotchWindowController?
    private var hotZone: HotZoneMonitor?
    private var hotKeys: HotKeyCenter?
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
    let mirrorFeature = MirrorFeature()
    let audioOutput = AudioOutputBridge()
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var welcomeWindow: NSWindow?

    nonisolated(unsafe) private static var weakSelf: AppDelegate?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.weakSelf = self
        installSignalHandlers()
        promptAccessibilityIfNeeded()
        showWelcomeIfFirstLaunch()

        mediaFeature = MediaFeature(bridge: mediaBridge, stateMachine: stateMachine)
        mediaFeature.start()

        btFeature = BTFeature(bridge: btBridge, stateMachine: stateMachine)
        btFeature.start()

        calendarFeature = CalendarFeature(bridge: eventBridge, stateMachine: stateMachine)
        Task { await calendarFeature.start() }

        timerFeature = TimerFeature(stateMachine: stateMachine)

        systemMonitor = SystemMonitorFeature(bridge: monitorBridge)
        systemMonitor.start()

        audioOutput.start()

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // Try a few SF Symbols, falling back to emoji if none exist.
        let candidates = [
            "moonphase.waxing.crescent",         // crescent moon = "Notchy" 🌒
            "moon.fill",
            "moon.stars.fill",
            "rectangle.topthird.inset.filled",  // last-resort notch shape
        ]
        var iconImage: NSImage?
        for name in candidates {
            if let img = NSImage(systemSymbolName: name, accessibilityDescription: "Notchy") {
                iconImage = img
                break
            }
        }
        if let icon = iconImage {
            let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
            let configured = icon.withSymbolConfiguration(config) ?? icon
            configured.isTemplate = true  // adapts to dark/light menu bar
            item.button?.image = configured
        } else {
            item.button?.title = "🌒"
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Welcome…", action: #selector(openWelcome), keyEquivalent: ""))
        let timerMenu = NSMenu()
        timerMenu.addItem(NSMenuItem(title: "25 minutes", action: #selector(startTimer25), keyEquivalent: ""))
        timerMenu.addItem(NSMenuItem(title: "15 minutes", action: #selector(startTimer15), keyEquivalent: ""))
        timerMenu.addItem(NSMenuItem(title: "5 minutes", action: #selector(startTimer5), keyEquivalent: ""))
        let timerItem = NSMenuItem(title: "Start Timer", action: nil, keyEquivalent: "")
        timerItem.submenu = timerMenu
        menu.addItem(timerItem)
        menu.addItem(NSMenuItem(title: "Mirror", action: #selector(openMirror), keyEquivalent: "m"))
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
        let mir = mirrorFeature
        let ao = audioOutput
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
                systemMonitor: smon,
                mirrorFeature: mir,
                audioOutput: ao
            )
        }
        windowController?.show()

        let monitor = HotZoneMonitor()
        monitor.onEnter = { [weak self] in self?.stateMachine.send(.hoverEntered) }
        monitor.onExit = { [weak self] in self?.stateMachine.send(.hoverExited) }
        monitor.onEscape = { [weak self] in self?.stateMachine.send(.escapeKeyPressed) }
        monitor.onClickOutside = { [weak self] in self?.stateMachine.send(.outsideClicked) }
        monitor.onHorizontalSwipe = { [weak self] direction in
            // Gated by Settings → Now Playing → swipe toggle.
            let enabled = UserDefaults.standard.object(forKey: "notchy.swipeEnabled") as? Bool ?? true
            guard enabled else { return }
            guard self?.mediaFeature.current != nil else { return }
            if direction > 0 { self?.mediaFeature.next() }
            else { self?.mediaFeature.prev() }
        }
        monitor.start()
        hotZone = monitor

        let hk = HotKeyCenter()
        hk.onAction = { [weak self] action in
            guard let self else { return }
            switch action {
            case .toggleDashboard:
                if self.stateMachine.state == .dashboard {
                    self.stateMachine.send(.hoverExited)
                } else {
                    if !self.stateMachine.state.isExpanded {
                        self.stateMachine.send(.hoverEntered)
                    }
                    self.stateMachine.send(.tabSwitchedTo(.dashboard))
                }
            case .toggleMirror:
                if self.stateMachine.state == .mirror {
                    self.stateMachine.send(.hoverExited)
                } else {
                    self.stateMachine.send(.mirrorRequested)
                }
            }
        }
        hk.start()
        hotKeys = hk

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
            _ = mediaFeature?.current  // also re-fire when media starts/stops
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

        // Grow / shrink hover keep-alive zone so cursor can move INTO the expanded
        // panel content (buttons, scrubber, etc.) without triggering collapse.
        hotZone?.isExpanded = stateMachine.state.isExpanded

        // Live-activity wings widen the collapsed hover zone whenever a track is
        // loaded (playing or paused), so cursor can hover the album art / waveform.
        let hasTrack = mediaFeature?.current != nil
        hotZone?.isLiveActivityVisible = hasTrack && !stateMachine.state.isExpanded

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

    private func showWelcomeIfFirstLaunch() {
        let key = "notchy.welcomeShown"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.openWelcome()
            UserDefaults.standard.set(true, forKey: key)
        }
    }

    @objc func openWelcome() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if welcomeWindow == nil {
            let hosting = NSHostingController(rootView: WelcomeView { [weak self] in
                self?.welcomeWindow?.close()
            })
            let win = NSWindow(contentViewController: hosting)
            win.title = "Welcome to Notchy"
            win.styleMask = [.titled, .closable]
            win.setContentSize(NSSize(width: 460, height: 540))
            win.isReleasedWhenClosed = false
            win.center()
            win.delegate = self
            welcomeWindow = win
        }
        welcomeWindow?.makeKeyAndOrderFront(nil)
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

    @objc func openMirror() {
        let line = "\(Date()) [Notchy.App] openMirror() called\n"
        if UserDefaults.standard.bool(forKey: "notchy.debugLogging") {
            try? line.data(using: .utf8)?.writeAppending(to: "/tmp/notchy.log")
        }
        stateMachine.send(.mirrorRequested)
        Task { await mirrorFeature.start() }
    }

    /// Trigger the system Accessibility prompt so Notchy appears in
    /// System Settings → Privacy & Security → Accessibility. Without this,
    /// NSEvent global monitors silently fail (return nil) and hover never fires.
    private func promptAccessibilityIfNeeded() {
        // Already trusted? Don't pop the prompt.
        if AXIsProcessTrusted() { return }
        // ad-hoc-signed dev builds get a fresh cdhash each rebuild → AXIsProcessTrusted
        // returns false even when the user thinks they granted permission. Don't
        // keep nagging — prompt once total per UserDefaults flag, then trust the user
        // to fix it manually if needed.
        let key = "notchy.hasPromptedAccessibilityV1"
        if UserDefaults.standard.bool(forKey: key) { return }
        let options = ["AXTrustedCheckOptionPrompt": kCFBooleanTrue!] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        UserDefaults.standard.set(true, forKey: key)
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
