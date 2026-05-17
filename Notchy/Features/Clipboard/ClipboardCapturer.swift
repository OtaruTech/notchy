import AppKit

fileprivate func _capLog(_ msg: String) {
    guard UserDefaults.standard.bool(forKey: "notchy.debugLogging") else { return }
    let line = "\(Date()) [Notchy.Clipboard] \(msg)\n"
    let path = "/tmp/notchy.log"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: path),
           let h = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
            h.seekToEndOfFile()
            try? h.write(contentsOf: data)
            try? h.close()
        } else {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}

/// Polls `NSPasteboard.general.changeCount` every 500 ms. On change, snapshots
/// the active item and hands it to the store (unless the source app is on the
/// exclusion list or the item is a concealed/transient type).
@MainActor
final class ClipboardCapturer {

    private let store: ClipboardStore
    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var lastInsertedHash: String?

    var onInsert: (ClipboardItem) -> Void = { _ in }

    init(store: ClipboardStore) {
        self.store = store
    }

    func start() {
        stop()
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        _capLog("capturer started")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard UserDefaults.standard.bool(forKey: "notchy.clipboardEnabled") else { return }
        if UserDefaults.standard.bool(forKey: "notchy.clipboardPaused") { return }

        let pb = NSPasteboard.general
        let count = pb.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count

        // Capture frontmost app NOW (before our panel could steal focus later).
        let front = NSWorkspace.shared.frontmostApplication
        let bundle = front?.bundleIdentifier
        let name = front?.localizedName

        // Exclusion check.
        if let bundle, isExcluded(bundle) {
            _capLog("skip — excluded bundle \(bundle)")
            return
        }

        guard let item = ItemKindDetector.snapshot(
            pasteboard: pb,
            sourceBundle: bundle,
            sourceName: name,
            imageDir: store.imagesDir
        ) else { return }

        // Dedup against the most recent inserted hash without going to disk.
        if item.contentHash == lastInsertedHash {
            _capLog("dedup (in-memory) \(item.kind.rawValue)")
            return
        }
        lastInsertedHash = item.contentHash

        let captured = item
        Task {
            do {
                let stored = try await store.insertOrBump(captured)
                await MainActor.run {
                    _capLog("insert \(stored.kind.rawValue) preview=\(stored.preview.prefix(40))")
                    self.onInsert(stored)
                }
            } catch {
                await MainActor.run {
                    _capLog("insert FAILED: \(error)")
                }
            }
        }
    }

    private func isExcluded(_ bundle: String) -> Bool {
        let raw = UserDefaults.standard.string(forKey: "notchy.clipboardExcludedBundleIDs")
            ?? Self.defaultExclusions
        let entries = raw.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        for entry in entries where !entry.isEmpty {
            if entry.hasSuffix("*") {
                let prefix = String(entry.dropLast())
                if bundle.hasPrefix(prefix) { return true }
            } else if bundle == entry {
                return true
            }
        }
        return false
    }

    static let defaultExclusions =
        "com.1password.macos,com.agilebits.onepassword*,com.bitwarden.desktop,com.apple.keychainaccess,com.lastpass.LastPass"
}
