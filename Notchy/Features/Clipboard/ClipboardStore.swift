import Foundation
import SQLite3

fileprivate let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Wraps libsqlite3 for clipboard persistence. No GRDB / SwiftPM deps.
///
/// Schema (v1):
/// ```
/// items(id TEXT PK, kind TEXT, content_hash TEXT, payload_text TEXT,
///       payload_path TEXT, preview TEXT, source_bundle TEXT, source_name TEXT,
///       byte_size INTEGER, created_at INTEGER, updated_at INTEGER,
///       pinned INTEGER, deleted_at INTEGER)
/// schema_version(version INTEGER)
/// ```
actor ClipboardStore {

    enum StoreError: Error {
        case openFailed(String)
        case prepareFailed(String)
        case stepFailed(String)
    }

    private var db: OpaquePointer?
    private let dbURL: URL
    let imagesDir: URL

    init(directory: URL) {
        self.dbURL = directory.appendingPathComponent("clipboard.sqlite")
        self.imagesDir = directory.appendingPathComponent("images")
    }

    func open() throws {
        try FileManager.default.createDirectory(
            at: dbURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        var handle: OpaquePointer?
        if sqlite3_open(dbURL.path, &handle) != SQLITE_OK {
            let msg = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(handle)
            throw StoreError.openFailed(msg)
        }
        db = handle
        // Lock the file down: rw for user only.
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: dbURL.path
        )
        try migrate()
    }

    func close() {
        if let db { sqlite3_close(db) }
        db = nil
    }

    // MARK: schema migration

    private func migrate() throws {
        try exec("""
            CREATE TABLE IF NOT EXISTS schema_version (version INTEGER NOT NULL);
            CREATE TABLE IF NOT EXISTS items (
                id TEXT PRIMARY KEY,
                kind TEXT NOT NULL,
                content_hash TEXT NOT NULL,
                payload_text TEXT,
                payload_path TEXT,
                preview TEXT NOT NULL,
                source_bundle TEXT,
                source_name TEXT,
                byte_size INTEGER NOT NULL DEFAULT 0,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                pinned INTEGER NOT NULL DEFAULT 0,
                deleted_at INTEGER
            );
            CREATE INDEX IF NOT EXISTS idx_items_updated
                ON items (updated_at DESC);
            CREATE INDEX IF NOT EXISTS idx_items_hash
                ON items (content_hash);
            CREATE INDEX IF NOT EXISTS idx_items_kind
                ON items (kind, updated_at DESC);
        """)
        // Set schema version if empty.
        if try scalarInt("SELECT count(*) FROM schema_version") == 0 {
            try exec("INSERT INTO schema_version (version) VALUES (1)")
        }
    }

    // MARK: writes

    /// Insert OR bump `updated_at` if an item with the same hash already exists.
    /// Returns the actually-stored item (with the persisted UUID).
    @discardableResult
    func insertOrBump(_ item: ClipboardItem) throws -> ClipboardItem {
        if let existingId = try findIdByHash(item.contentHash) {
            try touchUpdated(id: existingId, to: item.updatedAt)
            return ClipboardItem(
                id: existingId, kind: item.kind, contentHash: item.contentHash,
                payloadText: item.payloadText, payloadPath: item.payloadPath,
                preview: item.preview, sourceBundle: item.sourceBundle,
                sourceName: item.sourceName, byteSize: item.byteSize,
                createdAt: item.createdAt, updatedAt: item.updatedAt, pinned: item.pinned
            )
        }
        try insert(item)
        return item
    }

    private func insert(_ item: ClipboardItem) throws {
        let sql = """
            INSERT INTO items (id, kind, content_hash, payload_text, payload_path,
                               preview, source_bundle, source_name, byte_size,
                               created_at, updated_at, pinned, deleted_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL);
        """
        var stmt: OpaquePointer?
        try prepare(sql, &stmt)
        defer { sqlite3_finalize(stmt) }

        bindText(stmt, 1, item.id.uuidString)
        bindText(stmt, 2, item.kind.rawValue)
        bindText(stmt, 3, item.contentHash)
        bindTextOptional(stmt, 4, item.payloadText)
        bindTextOptional(stmt, 5, item.payloadPath?.absoluteString)
        bindText(stmt, 6, item.preview)
        bindTextOptional(stmt, 7, item.sourceBundle)
        bindTextOptional(stmt, 8, item.sourceName)
        sqlite3_bind_int64(stmt, 9, Int64(item.byteSize))
        sqlite3_bind_int64(stmt, 10, Int64(item.createdAt.timeIntervalSince1970))
        sqlite3_bind_int64(stmt, 11, Int64(item.updatedAt.timeIntervalSince1970))
        sqlite3_bind_int(stmt, 12, item.pinned ? 1 : 0)
        try step(stmt)
    }

    private func findIdByHash(_ hash: String) throws -> UUID? {
        let sql = "SELECT id FROM items WHERE content_hash = ? AND deleted_at IS NULL LIMIT 1"
        var stmt: OpaquePointer?
        try prepare(sql, &stmt)
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, hash)
        if sqlite3_step(stmt) == SQLITE_ROW {
            let s = String(cString: sqlite3_column_text(stmt, 0))
            return UUID(uuidString: s)
        }
        return nil
    }

    private func touchUpdated(id: UUID, to date: Date) throws {
        let sql = "UPDATE items SET updated_at = ? WHERE id = ?"
        var stmt: OpaquePointer?
        try prepare(sql, &stmt)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, Int64(date.timeIntervalSince1970))
        bindText(stmt, 2, id.uuidString)
        try step(stmt)
    }

    func softDelete(id: UUID) throws {
        let sql = "UPDATE items SET deleted_at = ? WHERE id = ?"
        var stmt: OpaquePointer?
        try prepare(sql, &stmt)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, Int64(Date().timeIntervalSince1970))
        bindText(stmt, 2, id.uuidString)
        try step(stmt)
    }

    func clearAll() throws {
        try exec("DELETE FROM items")
        // Also wipe image files.
        let files = (try? FileManager.default.contentsOfDirectory(at: imagesDir, includingPropertiesForKeys: nil)) ?? []
        for f in files { try? FileManager.default.removeItem(at: f) }
    }

    func purgeOlderThan(days: Int) throws -> Int {
        guard days > 0 else { return 0 }
        let cutoff = Date().addingTimeInterval(-Double(days) * 86_400).timeIntervalSince1970
        // First gather image paths to remove from disk.
        let imageRows = try select(
            "SELECT payload_path FROM items WHERE kind = 'image' AND updated_at < ? AND pinned = 0",
            bind: { sqlite3_bind_int64($0, 1, Int64(cutoff)) },
            map: { (stmt: OpaquePointer?) -> String? in
                guard sqlite3_column_type(stmt, 0) != SQLITE_NULL else { return nil }
                return String(cString: sqlite3_column_text(stmt, 0))
            }
        )
        for p in imageRows.compactMap({ $0 }) {
            if let url = URL(string: p) { try? FileManager.default.removeItem(at: url) }
        }
        let sql = "DELETE FROM items WHERE updated_at < ? AND pinned = 0"
        var stmt: OpaquePointer?
        try prepare(sql, &stmt)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, Int64(cutoff))
        try step(stmt)
        return Int(sqlite3_changes(db))
    }

    // MARK: reads

    func recent(limit: Int) throws -> [ClipboardItem] {
        let sql = """
            SELECT id, kind, content_hash, payload_text, payload_path, preview,
                   source_bundle, source_name, byte_size, created_at, updated_at, pinned
            FROM items WHERE deleted_at IS NULL
            ORDER BY updated_at DESC LIMIT ?
        """
        return try selectItems(sql, bind: { sqlite3_bind_int64($0, 1, Int64(limit)) })
    }

    func search(_ query: String, limit: Int) throws -> [ClipboardItem] {
        let sql = """
            SELECT id, kind, content_hash, payload_text, payload_path, preview,
                   source_bundle, source_name, byte_size, created_at, updated_at, pinned
            FROM items WHERE deleted_at IS NULL
              AND (preview LIKE ? OR payload_text LIKE ? OR source_name LIKE ?)
            ORDER BY updated_at DESC LIMIT ?
        """
        let needle = "%\(query)%"
        return try selectItems(sql, bind: { stmt in
            bindText(stmt, 1, needle)
            bindText(stmt, 2, needle)
            bindText(stmt, 3, needle)
            sqlite3_bind_int64(stmt, 4, Int64(limit))
        })
    }

    func count() throws -> Int {
        try scalarInt("SELECT count(*) FROM items WHERE deleted_at IS NULL")
    }

    // MARK: internals

    private func selectItems(_ sql: String, bind: (OpaquePointer?) throws -> Void) throws -> [ClipboardItem] {
        var stmt: OpaquePointer?
        try prepare(sql, &stmt)
        defer { sqlite3_finalize(stmt) }
        try bind(stmt)
        var out: [ClipboardItem] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let idStr = String(cString: sqlite3_column_text(stmt, 0))
            guard let id = UUID(uuidString: idStr) else { continue }
            let kindStr = String(cString: sqlite3_column_text(stmt, 1))
            guard let kind = ClipboardItem.Kind(rawValue: kindStr) else { continue }
            let hash = String(cString: sqlite3_column_text(stmt, 2))
            let payloadText: String? = textOrNil(stmt, 3)
            let payloadPath: URL? = textOrNil(stmt, 4).flatMap { URL(string: $0) }
            let preview = textOrNil(stmt, 5) ?? ""
            let bundle = textOrNil(stmt, 6)
            let name = textOrNil(stmt, 7)
            let byteSize = Int(sqlite3_column_int64(stmt, 8))
            let createdAt = Date(timeIntervalSince1970: Double(sqlite3_column_int64(stmt, 9)))
            let updatedAt = Date(timeIntervalSince1970: Double(sqlite3_column_int64(stmt, 10)))
            let pinned = sqlite3_column_int(stmt, 11) != 0
            out.append(ClipboardItem(
                id: id, kind: kind, contentHash: hash,
                payloadText: payloadText, payloadPath: payloadPath,
                preview: preview, sourceBundle: bundle, sourceName: name,
                byteSize: byteSize, createdAt: createdAt, updatedAt: updatedAt, pinned: pinned
            ))
        }
        return out
    }

    private func textOrNil(_ stmt: OpaquePointer?, _ col: Int32) -> String? {
        guard sqlite3_column_type(stmt, col) != SQLITE_NULL,
              let c = sqlite3_column_text(stmt, col) else { return nil }
        return String(cString: c)
    }

    private func select<T>(
        _ sql: String,
        bind: (OpaquePointer?) -> Void,
        map: (OpaquePointer?) -> T
    ) throws -> [T] {
        var stmt: OpaquePointer?
        try prepare(sql, &stmt)
        defer { sqlite3_finalize(stmt) }
        bind(stmt)
        var out: [T] = []
        while sqlite3_step(stmt) == SQLITE_ROW { out.append(map(stmt)) }
        return out
    }

    private func scalarInt(_ sql: String) throws -> Int {
        var stmt: OpaquePointer?
        try prepare(sql, &stmt)
        defer { sqlite3_finalize(stmt) }
        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int64(stmt, 0))
        }
        return 0
    }

    private func exec(_ sql: String) throws {
        var err: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
            let msg = err.map { String(cString: $0) } ?? "?"
            sqlite3_free(err)
            throw StoreError.stepFailed(msg)
        }
    }

    private func prepare(_ sql: String, _ stmt: inout OpaquePointer?) throws {
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw StoreError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    private func step(_ stmt: OpaquePointer?) throws {
        let r = sqlite3_step(stmt)
        if r != SQLITE_DONE && r != SQLITE_ROW {
            throw StoreError.stepFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    private func bindText(_ stmt: OpaquePointer?, _ idx: Int32, _ s: String) {
        sqlite3_bind_text(stmt, idx, s, -1, SQLITE_TRANSIENT)
    }

    private func bindTextOptional(_ stmt: OpaquePointer?, _ idx: Int32, _ s: String?) {
        if let s { sqlite3_bind_text(stmt, idx, s, -1, SQLITE_TRANSIENT) }
        else { sqlite3_bind_null(stmt, idx) }
    }
}
