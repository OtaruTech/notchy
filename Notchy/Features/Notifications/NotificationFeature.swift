import Foundation
import Observation
import AppKit

/// Holds the notification currently shown in the pill panel, plus a small
/// queue of pending notifications received while one is already on screen.
/// The dismiss timer runs on the main actor; sticky notifications skip the
/// timer entirely.
@MainActor
@Observable
final class NotificationFeature {

    private(set) var current: ExternalNotification?
    private var queue: [ExternalNotification] = []
    private var dismissTask: Task<Void, Never>?

    /// Replaces the current pill if non-sticky, otherwise queues.
    func push(_ note: ExternalNotification) {
        // De-dup: same id already shown / queued — replace rather than stack.
        if current?.id == note.id {
            current = note
            scheduleAutoDismiss(for: note)
            return
        }
        if let idx = queue.firstIndex(where: { $0.id == note.id }) {
            queue[idx] = note
            return
        }

        if let cur = current, cur.sticky {
            queue.append(note)
            return
        }
        current = note
        scheduleAutoDismiss(for: note)
    }

    /// User clicked the pill or pressed esc on it. Advances to the next
    /// queued notification, if any.
    func dismissCurrent() {
        dismissTask?.cancel()
        current = nil
        if !queue.isEmpty {
            let next = queue.removeFirst()
            current = next
            scheduleAutoDismiss(for: next)
        }
    }

    /// Click handler — opens the source cwd in the user's terminal app,
    /// then dismisses.
    func clickCurrent() {
        guard let cur = current else { return }
        if let cwd = cur.cwd, !cwd.isEmpty {
            openInTerminal(cwd: cwd)
        }
        dismissCurrent()
    }

    private func scheduleAutoDismiss(for note: ExternalNotification) {
        dismissTask?.cancel()
        guard !note.sticky else { return }
        let ttl = max(2.0, note.ttlSeconds)
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(ttl))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                // Only auto-dismiss if STILL showing this note. A push() during
                // sleep may have replaced it.
                if self?.current?.id == note.id {
                    self?.dismissCurrent()
                }
            }
        }
    }

    /// Best-effort: opens Terminal.app (or iTerm.app if frontmost terminal
    /// preference is iTerm) at the given cwd. Falls back to just activating
    /// the app if the AppleScript path fails.
    private func openInTerminal(cwd: String) {
        // Prefer iTerm if running, else Terminal.
        let useITerm = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.googlecode.iterm2"
        }
        let appName = useITerm ? "iTerm" : "Terminal"
        // Use NSWorkspace's open(_:configuration:) — safer than AppleScript and
        // doesn't require Automation permission.
        let url = URL(fileURLWithPath: cwd, isDirectory: true)
        let app = useITerm
            ? URL(fileURLWithPath: "/Applications/iTerm.app")
            : URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        if FileManager.default.fileExists(atPath: app.path) {
            let cfg = NSWorkspace.OpenConfiguration()
            cfg.activates = true
            NSWorkspace.shared.open([url], withApplicationAt: app, configuration: cfg)
        } else {
            // Last-ditch: activate whichever terminal is running.
            for runner in NSWorkspace.shared.runningApplications {
                if runner.localizedName == appName {
                    runner.activate(options: [.activateAllWindows])
                    return
                }
            }
        }
    }
}
