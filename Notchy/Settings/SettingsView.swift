import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("notchy.hintEnabled") private var hintEnabled = true
    @AppStorage("notchy.gaugeEnabled") private var gaugeEnabled = true
    @AppStorage("notchy.hoverDelayMs") private var hoverDelayMs = 120.0
    @AppStorage("notchy.swipeEnabled") private var swipeEnabled = true
    @AppStorage("notchy.debugLogging") private var debugLogging = false
    @AppStorage("notchy.hotkeysEnabled") private var hotkeysEnabled = true
    @AppStorage("notchy.lyricsEnabled") private var lyricsEnabled = false
    @AppStorage("notchy.clipboardEnabled") private var clipboardEnabled = true
    @AppStorage("notchy.clipboardRestore") private var clipboardRestore = true
    @AppStorage("notchy.clipboardCaptureImages") private var clipboardCaptureImages = true
    @AppStorage("notchy.clipboardRetentionDays") private var clipboardRetentionDays = 30
    @AppStorage("notchy.clipboardExcludedBundleIDs") private var clipboardExclusions =
        ClipboardCapturer.defaultExclusions

    // v0.4 — HUD
    @AppStorage("notchy.hudVolumeEnabled")    private var hudVolume = true
    @AppStorage("notchy.hudBrightnessEnabled") private var hudBrightness = true
    @AppStorage("notchy.hudKeyboardEnabled")   private var hudKeyboard = true
    @AppStorage("notchy.hudDuration")          private var hudDuration = 1.5

    // v0.4 — Indicators
    @AppStorage("notchy.indicatorChargingEnabled")  private var indCharging = true
    @AppStorage("notchy.indicatorPrivacyEnabled")   private var indPrivacy = true
    @AppStorage("notchy.indicatorCaffeineEnabled")  private var indCaffeine = true
    @AppStorage("notchy.indicatorNetworkEnabled")   private var indNetwork = true
    @AppStorage("notchy.indicatorNetworkHideIdle")  private var indNetworkHideIdle = true
    @AppStorage("notchy.indicatorBTDevicesEnabled") private var indBTDevices = true
    @AppStorage("notchy.indicatorIDEContextEnabled") private var indIDE = true
    @AppStorage("notchy.indicatorSSHEnabled")        private var indSSH = true
    @AppStorage("notchy.indicatorSSHDangerPattern")  private var sshDangerPattern = SSHMonitor.defaultDangerPattern

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var clearConfirmShown = false

    var body: some View {
        TabView {
            generalTab
            clipboardTab
            systemTab
            advancedTab
        }
        .padding()
        .frame(width: 520, height: 600)
    }

    // MARK: General

    private var generalTab: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue { try SMAppService.mainApp.register() }
                            else        { try SMAppService.mainApp.unregister() }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }
            Section("Hover trigger") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Hover delay")
                        Spacer()
                        Text("\(Int(hoverDelayMs)) ms")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $hoverDelayMs, in: 0...500, step: 20)
                    Text("How long to hover the notch before it expands. Lower = more responsive but may trigger by accident.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Now Playing") {
                Toggle("Show hint pill while media plays", isOn: $hintEnabled)
                Toggle("Two-finger horizontal swipe to switch track", isOn: $swipeEnabled)
                Toggle("Show synced lyrics below notch", isOn: $lyricsEnabled)
                Text("Lyrics fetched from lrclib.net. Only affects swipe + lyrics — pause/play buttons always work.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("System pill") {
                Toggle("Show CPU + battery readout in dashboard", isOn: $gaugeEnabled)
            }
            Section("Keyboard shortcuts") {
                Toggle("Enable global hotkeys", isOn: $hotkeysEnabled)
                VStack(alignment: .leading, spacing: 4) {
                    Label("⌘⌥N  toggle dashboard", systemImage: "square.grid.2x2.fill")
                    Label("⌘⌥M  toggle Mirror", systemImage: "video.fill")
                    Label("⌘⇧V  open clipboard panel", systemImage: "doc.on.clipboard")
                    Label("⌘⌥K  toggle Caffeine (keep awake)", systemImage: "cup.and.saucer.fill")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Text("Changes take effect on next launch.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
        .tabItem { Label("General", systemImage: "gearshape") }
    }

    // MARK: Clipboard

    private var clipboardTab: some View {
        Form {
            Section("Clipboard") {
                Toggle("Enable clipboard history", isOn: $clipboardEnabled)
                Toggle("Restore previous clipboard after paste", isOn: $clipboardRestore)
                Toggle("Capture images", isOn: $clipboardCaptureImages)
                Picker("Retention", selection: $clipboardRetentionDays) {
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                    Text("Never delete").tag(0)
                }
                Label("⌘⇧V  open clipboard panel", systemImage: "doc.on.clipboard")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Excluded apps") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Bundle IDs (comma-separated). Wildcards with `*` are allowed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $clipboardExclusions)
                        .frame(minHeight: 60)
                        .font(.system(size: 11, design: .monospaced))
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.gray.opacity(0.08))
                        )
                    Button("Reset to defaults") {
                        clipboardExclusions = ClipboardCapturer.defaultExclusions
                    }
                    .font(.caption)
                }
            }
            Section {
                Button("Clear all clipboard history…") { clearConfirmShown = true }
                    .foregroundStyle(.red)
                Button("Reveal data folder in Finder") {
                    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                        .appendingPathComponent("tech.otaru.Notchy", isDirectory: true)
                    NSWorkspace.shared.activateFileViewerSelecting([dir])
                }
            }
        }
        .formStyle(.grouped)
        .tabItem { Label("Clipboard", systemImage: "doc.on.clipboard") }
        .alert("Erase all clipboard history?", isPresented: $clearConfirmShown) {
            Button("Erase", role: .destructive) {
                Task { await (NSApp.delegate as? AppDelegate)?.clipboardFeature.clearAll() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This permanently removes all captured items and saved images. This cannot be undone.")
        }
    }

    // MARK: System (v0.4)

    private var systemTab: some View {
        Form {
            Section("HUD takeover") {
                Toggle("Replace volume HUD", isOn: $hudVolume)
                Toggle("Replace brightness HUD", isOn: $hudBrightness)
                Toggle("Replace keyboard backlight HUD", isOn: $hudKeyboard)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text("\(hudDuration, specifier: "%.1f") s")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $hudDuration, in: 0.5...4.0, step: 0.1)
                    Text("How long the HUD pill stays visible after a key press.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Indicators") {
                Toggle("Charging wattage", isOn: $indCharging)
                Toggle("Privacy indicators (mic / camera)", isOn: $indPrivacy)
                Toggle("Caffeine toggle (⌘⌥K)", isOn: $indCaffeine)
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Network speed", isOn: $indNetwork)
                    if indNetwork {
                        Toggle("Hide when idle (< 50 KB/s)", isOn: $indNetworkHideIdle)
                            .padding(.leading, 18)
                    }
                }
                Toggle("Bluetooth multi-device battery", isOn: $indBTDevices)
            }
            Section("Workflow (new in v0.5)") {
                Toggle("Meeting copilot — show countdown + Join button", isOn: .constant(true))
                    .disabled(true)
                Text("Auto-detects Zoom / Google Meet / Lark / Feishu / Teams / Tencent / Webex URLs in calendar events.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("VSCode / Cursor / Xcode project context", isOn: $indIDE)
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("SSH session indicator", isOn: $indSSH)
                    if indSSH {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Highlight in red when hostname matches:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("danger pattern (regex)", text: $sshDangerPattern)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11, design: .monospaced))
                        }
                        .padding(.leading, 18)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .tabItem { Label("System", systemImage: "switch.2") }
    }

    // MARK: Advanced

    private var advancedTab: some View {
        Form {
            Section("Debug") {
                Toggle("Verbose file logging", isOn: $debugLogging)
                Text("Writes to `/tmp/notchy.log`. Off by default. Enable when reporting a bug.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Reset") {
                Button("Reset all preferences") { resetAll() }
                    .foregroundStyle(.red)
            }
            Section("About") {
                HStack {
                    Image(systemName: "moonphase.waxing.crescent")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notchy v\(appVersion)").font(.system(size: 13, weight: .semibold))
                        Link("github.com/OtaruTech/notchy",
                             destination: URL(string: "https://github.com/OtaruTech/notchy")!)
                            .font(.caption)
                    }
                }
                Text("Free, open-source, MIT licensed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .tabItem { Label("Advanced", systemImage: "wrench.adjustable") }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    private func resetAll() {
        let keys = [
            "notchy.hintEnabled", "notchy.gaugeEnabled", "notchy.hoverDelayMs",
            "notchy.swipeEnabled", "notchy.debugLogging", "notchy.hotkeysEnabled",
            "notchy.lyricsEnabled", "notchy.clipboardEnabled",
            "notchy.clipboardRestore", "notchy.clipboardCaptureImages",
            "notchy.clipboardRetentionDays", "notchy.clipboardExcludedBundleIDs",
            "notchy.clipboardPaused",
            "notchy.hudVolumeEnabled", "notchy.hudBrightnessEnabled",
            "notchy.hudKeyboardEnabled", "notchy.hudDuration",
            "notchy.indicatorChargingEnabled", "notchy.indicatorPrivacyEnabled",
            "notchy.indicatorCaffeineEnabled", "notchy.indicatorNetworkEnabled",
            "notchy.indicatorNetworkHideIdle", "notchy.indicatorBTDevicesEnabled",
            "notchy.indicatorIDEContextEnabled", "notchy.indicatorSSHEnabled",
            "notchy.indicatorSSHDangerPattern",
            "notchy.hasPromptedAccessibilityV1", "notchy.welcomeShown",
        ]
        for k in keys { UserDefaults.standard.removeObject(forKey: k) }
    }
}
