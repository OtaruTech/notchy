import SwiftUI

/// Modal-style window content shown when a newer version is available.
struct UpdatePromptView: View {
    let current: SemVer
    let latest: UpdateChecker.ReleaseInfo
    let onDownload: () -> Void
    let onSkip: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 14) {
                Image(systemName: "moonphase.waxing.crescent")
                    .font(.system(size: 36, weight: .regular))
                    .foregroundStyle(.purple, .secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("A new version of Notchy is available")
                        .font(.system(size: 14, weight: .semibold))
                    Text("v\(current.display) → \(latest.tagName)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            // Changelog preview
            Text("What's new")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            ScrollView {
                Text(trimmedBody)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 220)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.gray.opacity(0.08))
            )

            // Footer note about Gatekeeper
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text("After download: unzip, drag to /Applications, run\n`xattr -dr com.apple.quarantine /Applications/Notchy.app`")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            HStack(spacing: 10) {
                Button("Skip this version") { onSkip() }
                Spacer()
                Button("Remind me later") { onLater() }
                Button("Download") { onDownload() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460, height: 460)
    }

    /// Strip leading markdown noise + truncate to ~1200 chars for the preview.
    private var trimmedBody: String {
        var s = latest.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return "(release has no description)" }
        if s.count > 1200 {
            let end = s.index(s.startIndex, offsetBy: 1200)
            s = String(s[..<end]) + "\n\n…\n\nFull changelog on GitHub."
        }
        return s
    }
}
