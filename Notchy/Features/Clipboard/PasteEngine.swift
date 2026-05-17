import AppKit
import Carbon.HIToolbox

/// Writes a `ClipboardItem` to the system pasteboard, refocuses the previous
/// app, synthesises a ⌘V keystroke, and optionally restores the user's prior
/// clipboard content shortly after.
@MainActor
enum PasteEngine {

    /// Returns true if the synthesised paste was scheduled. Even when true,
    /// some apps (sandboxed inputs, accessibility-blocked, etc.) may swallow
    /// the synthesised event — in those cases the item still ends up on the
    /// clipboard and the user can manually ⌘V.
    @discardableResult
    static func paste(
        item: ClipboardItem,
        to target: NSRunningApplication?,
        restorePrevious: Bool
    ) -> Bool {
        let priorSnapshot = snapshotPasteboard()
        writeToPasteboard(item)

        target?.activate(options: [.activateAllWindows])

        // Tiny delay so the target app has a frame to regain focus before
        // the keystroke fires.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
            synthesizeCmdV()
            if restorePrevious {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    restorePasteboard(priorSnapshot)
                }
            }
        }
        return true
    }

    // MARK: pasteboard I/O

    private static func writeToPasteboard(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.kind {
        case .image:
            if let path = item.payloadPath,
               let image = NSImage(contentsOf: path) {
                pb.writeObjects([image])
            }
        case .file:
            if let path = item.payloadPath {
                pb.writeObjects([path as NSURL])
            }
        case .richtext:
            if let text = item.payloadText,
               let data = text.data(using: .utf8) {
                pb.setData(data, forType: .rtf)
                // Also drop a plain-text fallback.
                if let attr = try? NSAttributedString(
                    data: data, options: [.documentType: NSAttributedString.DocumentType.rtf],
                    documentAttributes: nil
                ) {
                    pb.setString(attr.string, forType: .string)
                }
            }
        case .text, .url, .color, .code:
            if let text = item.payloadText {
                pb.setString(text, forType: .string)
            }
        }
    }

    // MARK: prior-clipboard snapshot / restore

    private struct Snapshot {
        let items: [[NSPasteboard.PasteboardType: Data]]
    }

    private static func snapshotPasteboard() -> Snapshot {
        let pb = NSPasteboard.general
        var captured: [[NSPasteboard.PasteboardType: Data]] = []
        for entry in pb.pasteboardItems ?? [] {
            var bucket: [NSPasteboard.PasteboardType: Data] = [:]
            for type in entry.types {
                if let data = entry.data(forType: type) {
                    bucket[type] = data
                }
            }
            captured.append(bucket)
        }
        return Snapshot(items: captured)
    }

    private static func restorePasteboard(_ snap: Snapshot) {
        guard !snap.items.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        let newItems: [NSPasteboardItem] = snap.items.map { bucket in
            let item = NSPasteboardItem()
            for (type, data) in bucket {
                item.setData(data, forType: type)
            }
            return item
        }
        pb.writeObjects(newItems)
    }

    // MARK: synthetic Cmd-V

    private static func synthesizeCmdV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey = CGKeyCode(kVK_ANSI_V)
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let up   = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
