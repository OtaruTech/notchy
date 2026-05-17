import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("notchy.hintEnabled") private var hintEnabled = true
    @AppStorage("notchy.gaugeEnabled") private var gaugeEnabled = true
    @AppStorage("notchy.hoverDelayMs") private var hoverDelayMs = 120.0
    @AppStorage("notchy.swipeEnabled") private var swipeEnabled = true
    @AppStorage("notchy.debugLogging") private var debugLogging = false
    @AppStorage("notchy.hotkeysEnabled") private var hotkeysEnabled = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

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
        .frame(width: 480, height: 440)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    private func resetAll() {
        let keys = ["notchy.hintEnabled", "notchy.gaugeEnabled", "notchy.hoverDelayMs",
                    "notchy.swipeEnabled", "notchy.debugLogging", "notchy.hotkeysEnabled",
                    "notchy.hasPromptedAccessibilityV1", "notchy.welcomeShown"]
        for k in keys { UserDefaults.standard.removeObject(forKey: k) }
    }
}
