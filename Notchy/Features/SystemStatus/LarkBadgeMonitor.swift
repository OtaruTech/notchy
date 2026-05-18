import AppKit
import ApplicationServices
import Foundation

/// Reads the macOS Dock's accessibility tree to find Lark / 飞书's tile and
/// extract its unread badge count.
///
/// The Dock process exposes one `AXList` whose `AXChildren` are tiles. Each
/// tile has `AXTitle` (app name) and, when badged, a child `AXStaticText`
/// whose `AXValue` reads e.g. "12 new items".  We strip non-digits and
/// publish the integer into `SystemStatusFeature.larkUnread`.
///
/// Polling cadence: 5s.  The Dock's AX tree is tiny so the read is cheap.
@MainActor
final class LarkBadgeMonitor {

    private let status: SystemStatusFeature
    private var pollTimer: Timer?

    /// App names we treat as "Lark". Localized variants included.
    private static let knownNames: Set<String> = [
        "Lark", "飞书", "Feishu"
    ]

    init(status: SystemStatusFeature) {
        self.status = status
    }

    func start() {
        refresh()
        let t = Timer(timeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(t, forMode: .common)
        pollTimer = t
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func refresh() {
        let snap = Self.readLarkTile()
        status.larkUnread = snap.unread
        status.larkBundleID = snap.bundleID
    }

    /// Returns `(unread, bundleID)` — `unread = 0` if no tile / no badge.
    private static func readLarkTile() -> (unread: Int, bundleID: String?) {
        guard let dockApp = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == "com.apple.dock"
        }) else {
            return (0, nil)
        }
        let dockAX = AXUIElementCreateApplication(dockApp.processIdentifier)
        guard let list = firstListChild(of: dockAX) else { return (0, nil) }
        guard let tiles = children(of: list) else { return (0, nil) }

        for tile in tiles {
            guard let title = stringAttr(tile, kAXTitleAttribute) else { continue }
            guard knownNames.contains(title) else { continue }
            let unread = badgeCount(of: tile)
            let bundleID = bundleIDForApp(named: title)
            return (unread, bundleID)
        }
        return (0, nil)
    }

    /// Walks the dock tile's children for an AXStaticText whose value parses
    /// as a number. Examples observed:
    ///   - "12 new items"        (English locale)
    ///   - "12 个新项"            (zh-Hans)
    ///   - "12"                   (no localisation suffix)
    private static func badgeCount(of tile: AXUIElement) -> Int {
        guard let kids = children(of: tile) else { return 0 }
        for child in kids {
            let role = stringAttr(child, kAXRoleAttribute) ?? ""
            guard role == kAXStaticTextRole as String else { continue }
            if let value = stringAttr(child, kAXValueAttribute),
               let n = leadingInt(in: value) {
                return n
            }
        }
        return 0
    }

    private static func leadingInt(in s: String) -> Int? {
        let digits = s.prefix { $0.isNumber }
        return Int(digits)
    }

    private static func firstListChild(of element: AXUIElement) -> AXUIElement? {
        guard let kids = children(of: element) else { return nil }
        for kid in kids {
            if stringAttr(kid, kAXRoleAttribute) == (kAXListRole as String) {
                return kid
            }
        }
        return nil
    }

    private static func children(of element: AXUIElement) -> [AXUIElement]? {
        var raw: CFTypeRef?
        let r = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &raw)
        guard r == .success, let arr = raw as? [AXUIElement] else { return nil }
        return arr
    }

    private static func stringAttr(_ element: AXUIElement, _ attr: String) -> String? {
        var raw: CFTypeRef?
        let r = AXUIElementCopyAttributeValue(element, attr as CFString, &raw)
        guard r == .success else { return nil }
        return raw as? String
    }

    private static func bundleIDForApp(named name: String) -> String? {
        NSWorkspace.shared.runningApplications.first { $0.localizedName == name }?.bundleIdentifier
    }

    // MARK: external action

    /// Activate Lark (used by dashboard click).
    @MainActor
    static func activateLark() {
        // Try by known names first (handles case where Lark isn't running yet
        // via runningApplications).
        for app in NSWorkspace.shared.runningApplications {
            if let name = app.localizedName, knownNames.contains(name) {
                app.activate(options: [.activateAllWindows])
                return
            }
        }
    }
}
