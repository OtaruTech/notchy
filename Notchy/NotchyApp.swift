import SwiftUI

@main
struct NotchyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        Settings {
            Text("Notchy settings (coming in Phase 6)")
                .padding()
                .frame(width: 360, height: 200)
        }
    }
}
