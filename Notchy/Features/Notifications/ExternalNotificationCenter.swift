import Foundation

/// Watches `~/Library/Application Support/tech.otaru.Notchy/inbox/` for new
/// JSON notification files dropped by external producers (Claude Code hook,
/// custom scripts). Files are read, parsed, forwarded to the supplied callback,
/// and **deleted** so each notification fires exactly once.
///
/// Uses a kqueue-backed `DispatchSource.makeFileSystemObjectSource` so the
/// directory mtime change triggers the watcher without polling. A 200ms
/// debounce coalesces multiple files dropped in the same instant.
@MainActor
final class ExternalNotificationCenter {

    private let inboxURL: URL
    private var dirHandle: FileHandle?
    private var source: DispatchSourceFileSystemObject?
    private var debounceTask: Task<Void, Never>?

    /// Called on the main actor for every successfully-parsed notification.
    var onReceive: (ExternalNotification) -> Void = { _ in }

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!.appendingPathComponent("tech.otaru.Notchy", isDirectory: true)
            .appendingPathComponent("inbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.inboxURL = dir
    }

    func start() {
        // Drain anything that arrived while Notchy was off.
        drain()
        installWatcher()
    }

    func stop() {
        source?.cancel()
        source = nil
        try? dirHandle?.close()
        dirHandle = nil
    }

    // MARK: directory watcher

    private func installWatcher() {
        let fd = open(inboxURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        dirHandle = handle
        let s = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend],
            queue: .main
        )
        s.setEventHandler { [weak self] in
            // Debounce — bursts of file writes (e.g. several hooks firing in
            // quick succession) shouldn't trigger N drains.
            self?.scheduleDrain()
        }
        s.setCancelHandler { close(fd) }
        s.resume()
        source = s
    }

    private func scheduleDrain() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.drain() }
        }
    }

    /// Read every `.json` file in the inbox, parse, emit, delete.
    /// Files that fail to parse get moved to `inbox/quarantine/` so a single
    /// bad producer can't wedge the pipeline.
    private func drain() {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: inboxURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else { return }

        // Sort oldest-first so notifications are delivered in arrival order.
        let jsonFiles = entries
            .filter { $0.pathExtension.lowercased() == "json" }
            .sorted { lhs, rhs in
                let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                return l < r
            }

        for file in jsonFiles {
            consume(file: file)
        }
    }

    private func consume(file: URL) {
        let fm = FileManager.default
        defer { try? fm.removeItem(at: file) }

        guard let data = try? Data(contentsOf: file) else { return }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            quarantine(file: file, reason: "not-json")
            return
        }
        let mtime = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate ?? Date()
        do {
            let note = try ExternalNotification.decode(from: json, receivedAt: mtime)
            onReceive(note)
        } catch {
            quarantine(file: file, reason: "decode-failed")
        }
    }

    private func quarantine(file: URL, reason: String) {
        let qdir = inboxURL.appendingPathComponent("quarantine", isDirectory: true)
        try? FileManager.default.createDirectory(at: qdir, withIntermediateDirectories: true)
        let dest = qdir.appendingPathComponent("\(reason)-\(file.lastPathComponent)")
        try? FileManager.default.moveItem(at: file, to: dest)
    }
}
