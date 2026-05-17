import SwiftUI
import AppKit

/// Shown the first time a user opens Notchy. Explains the core gestures and
/// points to System Settings for the required permissions.
struct WelcomeView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "moonphase.waxing.crescent")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.white)
                    .padding(.top, 32)
                Text("Welcome to Notchy")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Your MacBook's notch, but useful.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
            .background(LinearGradient(colors: [.black, Color(red: 0.10, green: 0.12, blue: 0.20)],
                                       startPoint: .top, endPoint: .bottom))

            // Feature rows
            VStack(alignment: .leading, spacing: 18) {
                row(icon: "hand.point.up.left.fill",
                    title: "Hover the notch",
                    text: "Expands a panel with media controls, calendar, system stats.")
                row(icon: "arrow.left.and.right",
                    title: "Two-finger swipe",
                    text: "Skip tracks horizontally over the notch — like a giant scrubber.")
                row(icon: "tray.full.fill",
                    title: "Drop a file on the notch",
                    text: "Hold files temporarily, AirDrop or Email them in one click.")
                row(icon: "video.fill",
                    title: "Mirror",
                    text: "Quick camera preview before video calls — from the menu bar.")
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)

            Divider()

            // Permissions hint
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(.orange)
                    Text("On first use you'll be prompted for")
                        .font(.system(size: 12))
                }
                Text("Accessibility (hover) · Bluetooth (AirPods) · Calendar · Camera (Mirror)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            // Done button
            Button("Get started") { onDismiss() }
                .keyboardShortcut(.return)
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 24)
        }
        .frame(width: 460, height: 540)
    }

    @ViewBuilder
    private func row(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.18))
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(text).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}
