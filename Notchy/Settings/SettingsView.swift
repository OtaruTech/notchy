import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("notchy.hintEnabled") private var hintEnabled = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
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
            Section("Now Playing") {
                Toggle("Show hint pill while media plays", isOn: $hintEnabled)
            }
            Section("About") {
                Text("Notchy v0.1.0")
                Text("github.com/OtaruTech/notchy")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 420, height: 320)
    }
}
