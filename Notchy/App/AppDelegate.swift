import AppKit
import SwiftUI

fileprivate func _clipLog(_ msg: String) {
    guard UserDefaults.standard.bool(forKey: "notchy.debugLogging") else { return }
    let line = "\(Date()) [Notchy.Clip] \(msg)\n"
    let path = "/tmp/notchy.log"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: path),
           let h = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
            h.seekToEndOfFile()
            try? h.write(contentsOf: data)
            try? h.close()
        } else {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}

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
    let lyricsBridge = LyricsBridge()
    private(set) var lyricsFeature: LyricsFeature!
    private(set) var clipboardStore: ClipboardStore!
    private(set) var clipboardFeature: ClipboardFeature!
    private(set) var clipboardSyncEngine: SyncEngine!
    private var clipboardCapturer: ClipboardCapturer?
    fileprivate var clipboardTargetApp: NSRunningApplication?
    private var clipboardPauseMenuItem: NSMenuItem?
    private var clipboardKeyMonitor: Any?
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

        lyricsFeature = LyricsFeature(bridge: lyricsBridge, mediaFeature: mediaFeature)
        lyricsFeature.start()

        // Clipboard: default to enabled unless the user explicitly turned it off.
        if UserDefaults.standard.object(forKey: "notchy.clipboardEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "notchy.clipboardEnabled")
        }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("tech.otaru.Notchy", isDirectory: true)
        clipboardStore = ClipboardStore(directory: appSupport)
        // Phase A: NoopSyncEngine. Phase B (after $99 dev account + iCloud
        // container provisioning) flips this to:
        //   clipboardSyncEngine = CloudKitSyncEngine(containerID: "iCloud.tech.otaru.Notchy")
        clipboardSyncEngine = NoopSyncEngine()
        clipboardFeature = ClipboardFeature(store: clipboardStore, syncEngine: clipboardSyncEngine)
        Task {
            do { try await clipboardStore.open() } catch { NSLog("[Notchy] clipboard open failed: \(error)") }
            await clipboardFeature.bootstrap()
            // Purge old items on launch (best-effort).
            let retention = UserDefaults.standard.object(forKey: "notchy.clipboardRetentionDays") as? Int ?? 30
            _ = try? await clipboardStore.purgeOlderThan(days: retention)
            clipboardSyncEngine.start(store: clipboardStore)
        }
        let capturer = ClipboardCapturer(store: clipboardStore)
        capturer.onInsert = { [weak self] item in
            self?.clipboardFeature.noteInserted(item)
        }
        capturer.start()
        clipboardCapturer = capturer

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
        menu.addItem(.separator())
        let pauseItem = NSMenuItem(
            title: UserDefaults.standard.bool(forKey: "notchy.clipboardPaused")
                ? "Resume Clipboard Capture"
                : "Pause Clipboard Capture",
            action: #selector(toggleClipboardPaused),
            keyEquivalent: ""
        )
        menu.addItem(pauseItem)
        clipboardPauseMenuItem = pauseItem
        menu.addItem(.separator())
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
        let lyrics = lyricsFeature!
        let clip = clipboardFeature!
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
                audioOutput: ao,
                lyricsFeature: lyrics,
                clipboardFeature: clip,
                onClipboardPaste: { [weak self] item in
                    self?.performClipboardPaste(item)
                },
                onClipboardDismiss: { [weak self] in
                    self?.dismissClipboardPanel()
                }
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
            case .toggleClipboard:
                _clipLog("hotkey ⌘⇧V received state=\(self.stateMachine.state)")
                if self.stateMachine.state == .clipboard {
                    self.dismissClipboardPanel()
                } else {
                    self.openClipboardPanel()
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
        drag.onExit = { /* no auto-dismiss */ }
        drag.onDrop = { [weak self] urls in
            self?.dropFeature.add(urls: urls)
        }
        // Install both: the in-panel intermediary (catches drags once the
        // panel is already expanded into .drop) AND a dedicated tiny
        // always-on drag-target panel sitting over the hardware notch (catches
        // the INITIAL drag-enter while the main panel is click-through).
        if let cv = windowController?.contentView {
            drag.attach(to: cv)
        }
        windowController?.installDragTarget(handler: drag)
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
        // Toggle click-through on the main panel:
        //   idle/hint → ignoresMouseEvents = true, full click-through.
        //              Drag detection still works via the separate
        //              `dragTargetPanel` that always receives mouse events.
        //   expanded → ignoresMouseEvents = false, SwiftUI captures clicks.
        windowController?.setIgnoresMouseEvents(!stateMachine.state.isExpanded)

        // Grow / shrink hover keep-alive zone so cursor can move INTO the expanded
        // panel content (buttons, scrubber, etc.) without triggering collapse.
        hotZone?.isExpanded = stateMachine.state.isExpanded
        // Clipboard panel gets a larger hover zone AND ignores hover-leave —
        // it should only dismiss on Esc / click-outside / paste, never on
        // cursor movement.
        hotZone?.isClipboardPanel = stateMachine.state == .clipboard
        // Drop tray also stays open until explicitly closed.
        hotZone?.isDropPanel = stateMachine.state == .drop

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

    /// Returns the rect (in hosting-view coordinates) inside which the panel
    /// should receive clicks. Everywhere else falls through to the underlying
    /// app. The panel canvas is 920×320 at the top of the notched screen with
    /// origin (0,0) at top-left; the active region varies by state:
    ///   - expanded clipboard:  centered 880×320
    ///   - expanded other:      centered 540×220
    ///   - collapsed with media or timer: the live-activity strip area
    ///   - collapsed bare:      just the hardware notch hot zone
    private func activeClickRect() -> CGRect {
        let panelW: CGFloat = 920
        let panelH: CGFloat = 320

        let state = stateMachine.state
        if state == .clipboard {
            let w: CGFloat = 880
            let h: CGFloat = 320
            return CGRect(x: (panelW - w) / 2, y: 0, width: w, height: h)
        }
        if state.isExpanded {
            let w: CGFloat = 540
            let h: CGFloat = 220
            return CGRect(x: (panelW - w) / 2, y: 0, width: w, height: h)
        }
        // Collapsed: just the strip/notch area.
        let notchW = ScreenGeometry.liveNotchWidth()
        let notchH = ScreenGeometry.liveNotchHeight()
        let hasMedia = mediaFeature?.current != nil
        let hasTimer = timerFeature?.state != .idle
        let wings: CGFloat = (hasMedia || hasTimer) ? 140 : 0
        let activeW = notchW + wings
        let extraBelow: CGFloat = (hasMedia || hasTimer) ? 28 : 0  // strip + small breathing room
        let activeH = notchH + extraBelow
        return CGRect(
            x: (panelW - activeW) / 2,
            y: 0,
            width: activeW,
            height: activeH
        )
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

    /// Open the clipboard panel — snapshot the previously-frontmost app so
    /// we can paste back into it later, then actively grab focus so SwiftUI
    /// receives keystrokes (TextField search + our 1-9/Enter/Esc monitor).
    /// Notchy temporarily switches to `.regular` activation policy so it can
    /// be the frontmost app while the panel is open.
    private func openClipboardPanel() {
        clipboardTargetApp = NSWorkspace.shared.frontmostApplication
        _clipLog("openClipboardPanel target=\(clipboardTargetApp?.localizedName ?? "<nil>") items=\(clipboardFeature.displayed.count)")
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        stateMachine.send(.clipboardRequested)
        installClipboardKeyMonitor()
    }

    /// Window-level event monitor — intercepts keystrokes while the clipboard
    /// panel is open, so 1-9 / Enter / Esc / arrows reach our paste logic
    /// even though SwiftUI's TextField holds focus for the search box.
    private func installClipboardKeyMonitor() {
        if clipboardKeyMonitor != nil { return }
        _clipLog("keyMonitor installed (frontmost=\(NSWorkspace.shared.frontmostApplication?.localizedName ?? "?"))")
        clipboardKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            _clipLog("keyDown code=\(event.keyCode) chars=\(event.charactersIgnoringModifiers ?? "?") state=\(self?.stateMachine.state ?? .idle)")
            guard let self, self.stateMachine.state == .clipboard else { return event }
            switch event.keyCode {
            case 53: // esc
                self.dismissClipboardPanel()
                return nil
            case 36, 76: // return / enter
                let items = self.clipboardFeature.displayed
                let idx = self.clipboardFeature.selectedIndex
                if idx < items.count {
                    self.performClipboardPaste(items[idx])
                }
                return nil
            case 123: // ← left arrow
                self.clipboardFeature.moveSelection(by: -1)
                return nil
            case 124: // → right arrow
                self.clipboardFeature.moveSelection(by: 1)
                return nil
            default:
                break
            }
            // Numeric quick-paste — match by character (handles both top-row
            // ANSI 1-9 and the numeric keypad regardless of layout). Only
            // when no modifiers are held.
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if mods.isEmpty || mods == .numericPad,
               let ch = event.charactersIgnoringModifiers,
               let digit = Int(ch),
               digit >= 1, digit <= 9
            {
                let items = self.clipboardFeature.displayed
                if digit - 1 < items.count {
                    self.performClipboardPaste(items[digit - 1])
                    return nil
                }
            }
            return event
        }
    }

    private func removeClipboardKeyMonitor() {
        if let m = clipboardKeyMonitor {
            NSEvent.removeMonitor(m)
            clipboardKeyMonitor = nil
        }
    }

    private func dismissClipboardPanel() {
        let target = clipboardTargetApp
        clipboardTargetApp = nil
        clipboardFeature.query = ""
        stateMachine.send(.hoverExited)
        windowController?.resignKey()
        removeClipboardKeyMonitor()
        // Drop back to accessory so we don't appear in Cmd-Tab.
        NSApp.setActivationPolicy(.accessory)
        target?.activate(options: [.activateAllWindows])
    }

    private func performClipboardPaste(_ item: ClipboardItem) {
        let target = clipboardTargetApp
        clipboardTargetApp = nil
        _clipLog("performPaste kind=\(item.kind.rawValue) target=\(target?.localizedName ?? "<nil>")")
        clipboardFeature.query = ""
        stateMachine.send(.hoverExited)
        windowController?.resignKey()
        removeClipboardKeyMonitor()
        NSApp.setActivationPolicy(.accessory)
        let restore = UserDefaults.standard.object(forKey: "notchy.clipboardRestore") as? Bool ?? true
        PasteEngine.paste(item: item, to: target, restorePrevious: restore)
    }

    @objc func toggleClipboardPaused() {
        let current = UserDefaults.standard.bool(forKey: "notchy.clipboardPaused")
        UserDefaults.standard.set(!current, forKey: "notchy.clipboardPaused")
        clipboardPauseMenuItem?.title = !current
            ? "Resume Clipboard Capture"
            : "Pause Clipboard Capture"
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
