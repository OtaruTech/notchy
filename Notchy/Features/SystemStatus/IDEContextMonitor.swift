import AppKit
import Foundation

/// Watches the frontmost app. When it's VSCode / Cursor / Xcode, parses the
/// window title to extract the project name and reads the git branch from
/// disk if a workspace path can be inferred. Pushes the result into
/// SystemStatusFeature.ideContext.
@MainActor
final class IDEContextMonitor {

    private let status: SystemStatusFeature
    private var pollTimer: Timer?
    private var observer: NSObjectProtocol?
    private var branchCache: [String: (branch: String, expires: Date)] = [:]

    init(status: SystemStatusFeature) {
        self.status = status
    }

    func start() {
        refresh()
        // Frontmost-app change → instant refresh.
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        // Plus 5s polling so the row reflects file switches inside the IDE.
        let t = Timer(timeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(t, forMode: .common)
        pollTimer = t
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        if let o = observer { NSWorkspace.shared.notificationCenter.removeObserver(o) }
    }

    private func refresh() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier
        else {
            status.ideContext = nil
            return
        }
        guard let editor = Self.editor(forBundleID: bundleID) else {
            status.ideContext = nil
            return
        }
        // Window title via Accessibility — keeps user permission already granted.
        let title = frontWindowTitle(pid: app.processIdentifier) ?? ""
        guard let projectName = Self.extractProject(title: title, editor: editor) else {
            status.ideContext = nil
            return
        }
        let branch = branchForProject(named: projectName)
        status.ideContext = SystemStatusFeature.IDEContext(
            editor: editor, projectName: projectName, branch: branch
        )
    }

    // MARK: window title extraction

    private func frontWindowTitle(pid: pid_t) -> String? {
        let app = AXUIElementCreateApplication(pid)
        var raw: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &raw)
        guard result == .success, let window = raw else { return nil }
        var titleRaw: CFTypeRef?
        let r2 = AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &titleRaw)
        guard r2 == .success, let title = titleRaw as? String else { return nil }
        return title
    }

    // MARK: editor classification + title parsing

    private static func editor(forBundleID bundleID: String) -> SystemStatusFeature.IDEContext.Editor? {
        switch bundleID {
        case "com.microsoft.VSCode":          return .vscode
        case "com.todesktop.230313mzl4w4u92": return .cursor   // Cursor's bundle ID
        case "com.apple.dt.Xcode":            return .xcode
        case "com.exafunction.windsurf":      return .windsurf
        default: return nil
        }
    }

    /// Title formats observed:
    /// - VSCode:  "filename.swift — projectname"
    /// - Cursor:  "filename.swift - projectname"
    /// - Xcode:   "ProjectName" or "WorkspaceName — fileName"
    /// - Windsurf: "filename - projectname"
    static func extractProject(title: String, editor: SystemStatusFeature.IDEContext.Editor) -> String? {
        guard !title.isEmpty else { return nil }
        // Split on em-dash or " - ". Last component is project.
        let separators: [Character] = ["—", "–", "-"]
        let parts = title.split { ch in
            separators.contains(ch)
        }.map { $0.trimmingCharacters(in: .whitespaces) }

        switch editor {
        case .vscode:
            // Strip trailing "Visual Studio Code" suffix if present.
            return parts.last.map { last in
                last == "Visual Studio Code" ? (parts.dropLast().last ?? "") : last
            }
        case .cursor, .windsurf:
            // Cursor often appends "Cursor" or product name; pick last non-product part.
            let product = (editor == .cursor) ? "Cursor" : "Windsurf"
            for candidate in parts.reversed() {
                if candidate != product && !candidate.isEmpty { return candidate }
            }
            return parts.last
        case .xcode:
            return parts.first
        }
    }

    // MARK: git branch

    private func branchForProject(named name: String) -> String? {
        if let cached = branchCache[name], cached.expires > Date() {
            return cached.branch
        }
        // Best-effort: scan common project roots for a folder matching the name.
        let candidates = ["~/workspace", "~/Code", "~/Developer", "~/Projects", "~/Documents", "~"]
            .map { ($0 as NSString).expandingTildeInPath }
        let fm = FileManager.default
        for root in candidates {
            let path = "\(root)/\(name)"
            if fm.fileExists(atPath: path) {
                if let branch = readGitBranch(at: path) {
                    branchCache[name] = (branch, Date().addingTimeInterval(30))
                    return branch
                }
            }
        }
        return nil
    }

    private func readGitBranch(at path: String) -> String? {
        let head = "\(path)/.git/HEAD"
        guard let contents = try? String(contentsOfFile: head, encoding: .utf8) else { return nil }
        let trimmed = contents.trimmingCharacters(in: .whitespacesAndNewlines)
        // "ref: refs/heads/main" → "main"
        if trimmed.hasPrefix("ref: refs/heads/") {
            return String(trimmed.dropFirst("ref: refs/heads/".count))
        }
        // Detached HEAD — show short hash.
        return String(trimmed.prefix(7))
    }
}
