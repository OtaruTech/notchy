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
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var clearConfirmShown = false

    var body: some View {
        TabView {
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
                    Text("Off by default. When on, fetches synced LRC from lrclib.net and shows the current line below the notch.")
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
        .padding()
        .frame(width: 520, height: 560)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    private func resetAll() {
        let keys = ["notchy.hintEnabled", "notchy.gaugeEnabled", "notchy.hoverDelayMs",
                    "notchy.swipeEnabled", "notchy.debugLogging", "notchy.hotkeysEnabled",
                    "notchy.lyricsEnabled", "notchy.clipboardEnabled",
                    "notchy.clipboardRestore", "notchy.clipboardCaptureImages",
                    "notchy.clipboardRetentionDays", "notchy.clipboardExcludedBundleIDs",
                    "notchy.clipboardPaused",
                    "notchy.hasPromptedAccessibilityV1", "notchy.welcomeShown"]
        for k in keys { UserDefaults.standard.removeObject(forKey: k) }
    }
}
