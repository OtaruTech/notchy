import AppKit
import SwiftUI

/// Top-level update flow controller. Wired in by AppDelegate:
///   - At launch (debounced to 1×/day) → background check; if newer, prompt
///   - Menu bar "Check for updates…" → unconditional check, always shows a
///     result (newer version OR "you're up to date")
///
/// Decisions:
///   - Ad-hoc-signed app cannot safely auto-install — so the prompt opens
///     the GitHub release page and lets the user re-download + re-`xattr`
///   - "Skip this version" stores the tag in `notchy.updateSkippedVersion`;
///     auto-check no longer prompts for that exact version (but manual still
///     shows it).
@MainActor
final class UpdateController {

    private let checker = UpdateChecker()
    private var window: NSWindow?

    /// Background check, debounced to 1×/day. Silent on no-update.
    func checkOnLaunchIfDue() {
        guard UserDefaults.standard.object(forKey: "notchy.checkForUpdates") as? Bool ?? true else { return }
        let lastTs = UserDefaults.standard.double(forKey: "notchy.lastUpdateCheck")
        let now = Date().timeIntervalSince1970
        // 23 h debounce so it doesn't fire every restart.
        if lastTs > 0, now - lastTs < 23 * 3600 { return }
        Task { await runCheck(manual: false) }
    }

    /// Triggered from the menu bar item. Always presents a result.
    func checkNow() {
        Task { await runCheck(manual: true) }
    }

    // MARK: core flow

    private func runCheck(manual: Bool) async {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "notchy.lastUpdateCheck")

        let info: UpdateChecker.ReleaseInfo
        do {
            info = try await checker.fetchLatest()
        } catch {
            if manual { presentError(error) }
            return
        }

        let currentString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        guard let current = SemVer(currentString) else { return }

        if info.version <= current {
            if manual { presentUpToDate(current: current) }
            return
        }

        // Auto-check honours "skip this version"; manual ignores it.
        if !manual,
           let skipped = UserDefaults.standard.string(forKey: "notchy.updateSkippedVersion"),
           skipped == info.tagName {
            return
        }

        presentUpdateAvailable(info: info, current: current)
    }

    // MARK: panels

    private func presentUpdateAvailable(info: UpdateChecker.ReleaseInfo, current: SemVer) {
        let root = UpdatePromptView(
            current: current,
            latest: info,
            onDownload: { [weak self] in
                NSWorkspace.shared.open(info.htmlURL)
                self?.dismiss()
            },
            onSkip: { [weak self] in
                UserDefaults.standard.set(info.tagName, forKey: "notchy.updateSkippedVersion")
                self?.dismiss()
            },
            onLater: { [weak self] in self?.dismiss() }
        )
        show(rootView: root, title: "Notchy update available")
    }

    private func presentUpToDate(current: SemVer) {
        let alert = NSAlert()
        alert.messageText = "You're on the latest version"
        alert.informativeText = "Notchy \(current.display) is the current release."
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func presentError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Couldn't check for updates"
        alert.informativeText = errorMessage(for: error)
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func errorMessage(for error: Error) -> String {
        guard let e = error as? UpdateChecker.CheckError else { return error.localizedDescription }
        switch e {
        case .noNetwork:           return "No network connection."
        case .rateLimited:         return "GitHub rate-limited the request. Try again in an hour."
        case .malformedResponse:   return "GitHub returned an unexpected response."
        case .tagNotParseable(let t): return "Couldn't parse the release tag \(t)."
        }
    }

    // MARK: window plumbing

    private func show(rootView: some View, title: String) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if window == nil {
            let host = NSHostingController(rootView: AnyView(rootView))
            let w = NSWindow(contentViewController: host)
            w.title = title
            w.styleMask = [.titled, .closable]
            w.setContentSize(NSSize(width: 460, height: 460))
            w.center()
            w.isReleasedWhenClosed = false
            window = w
        } else if let w = window {
            let host = NSHostingController(rootView: AnyView(rootView))
            w.contentViewController = host
        }
        window?.makeKeyAndOrderFront(nil)
    }

    private func dismiss() {
        window?.close()
        // LSUIElement accessory: drop activation policy back so the app icon
        // doesn't linger in the Dock.
        NSApp.setActivationPolicy(.accessory)
    }
}
