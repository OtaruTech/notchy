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
        try migrateV1toV2()
    }

    /// v1 → v2: add cloud-sync metadata columns + dedicated index for the
    /// "items needing push" queue. Columns are nullable so existing v1 rows
    /// keep working unchanged.
    private func migrateV1toV2() throws {
        let current = try scalarInt("SELECT max(version) FROM schema_version")
        guard current < 2 else { return }
        // `ALTER TABLE ADD COLUMN` is the only schema change SQLite supports
        // without rewriting. All three columns default to NULL / 0 which
        // matches "never synced, needs push on next run".
        try exec("ALTER TABLE items ADD COLUMN cloud_record_id TEXT")
        try exec("ALTER TABLE items ADD COLUMN cloud_modified_at INTEGER")
        try exec("ALTER TABLE items ADD COLUMN needs_sync INTEGER NOT NULL DEFAULT 1")
        try exec("CREATE INDEX IF NOT EXISTS idx_items_needs_sync ON items (needs_sync) WHERE needs_sync = 1")
        try exec("INSERT INTO schema_version (version) VALUES (2)")
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
                createdAt: item.createdAt, updatedAt: item.updatedAt, pinned: item.pinned,
                cloudRecordID: nil, cloudModifiedAt: nil, needsSync: true
            )
        }
        try insert(item)
        return item
    }

    private func insert(_ item: ClipboardItem) throws {
        let sql = """
            INSERT INTO items (id, kind, content_hash, payload_text, payload_path,
                               preview, source_bundle, source_name, byte_size,
                               created_at, updated_at, pinned, deleted_at,
                               cloud_record_id, cloud_modified_at, needs_sync)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, ?, ?);
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
        bindTextOptional(stmt, 13, item.cloudRecordID)
        if let cma = item.cloudModifiedAt {
            sqlite3_bind_int64(stmt, 14, Int64(cma.timeIntervalSince1970))
        } else {
            sqlite3_bind_null(stmt, 14)
        }
        sqlite3_bind_int(stmt, 15, item.needsSync ? 1 : 0)
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
        // Dedupe bump → still a local change, still needs push.
        let sql = "UPDATE items SET updated_at = ?, needs_sync = 1 WHERE id = ?"
        var stmt: OpaquePointer?
        try prepare(sql, &stmt)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, Int64(date.timeIntervalSince1970))
        bindText(stmt, 2, id.uuidString)
        try step(stmt)
    }

    func softDelete(id: UUID) throws {
        // Mark needs_sync = 1 too so the engine pushes the tombstone next run.
        let sql = "UPDATE items SET deleted_at = ?, needs_sync = 1 WHERE id = ?"
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

    private static let baseSelectColumns = """
        id, kind, content_hash, payload_text, payload_path, preview,
        source_bundle, source_name, byte_size, created_at, updated_at, pinned,
        cloud_record_id, cloud_modified_at, needs_sync
    """

    func recent(limit: Int) throws -> [ClipboardItem] {
        let sql = """
            SELECT \(Self.baseSelectColumns)
            FROM items WHERE deleted_at IS NULL
            ORDER BY updated_at DESC LIMIT ?
        """
        return try selectItems(sql, bind: { sqlite3_bind_int64($0, 1, Int64(limit)) })
    }

    func search(_ query: String, limit: Int) throws -> [ClipboardItem] {
        let sql = """
            SELECT \(Self.baseSelectColumns)
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

    // MARK: sync queries

    /// Items with local changes that haven't been pushed to CloudKit yet.
    /// Includes soft-deleted rows so the engine can issue a remote delete.
    func itemsNeedingSync(limit: Int) throws -> [ClipboardItem] {
        let sql = """
            SELECT \(Self.baseSelectColumns)
            FROM items WHERE needs_sync = 1
            ORDER BY updated_at ASC LIMIT ?
        """
        return try selectItems(sql, bind: { sqlite3_bind_int64($0, 1, Int64(limit)) })
    }

    /// Called by the sync engine after a successful push — clears the dirty
    /// flag and records the CloudKit record name + push timestamp.
    func markSynced(id: UUID, cloudRecordID: String, cloudModifiedAt: Date) throws {
        let sql = """
            UPDATE items SET needs_sync = 0,
                             cloud_record_id = ?,
                             cloud_modified_at = ?
            WHERE id = ?
        """
        var stmt: OpaquePointer?
        try prepare(sql, &stmt)
        defer { sqlite3_finalize(stmt) }
        bindText(stmt, 1, cloudRecordID)
        sqlite3_bind_int64(stmt, 2, Int64(cloudModifiedAt.timeIntervalSince1970))
        bindText(stmt, 3, id.uuidString)
        try step(stmt)
    }

    /// Apply a remote upsert from CloudKit (insert if missing, replace if
    /// the remote `cloudModifiedAt` is newer than the local one). Skips the
    /// `needs_sync` bump because this change *came from* CloudKit.
    func applyRemoteUpsert(_ item: ClipboardItem) throws {
        let sql = """
            INSERT INTO items (id, kind, content_hash, payload_text, payload_path,
                               preview, source_bundle, source_name, byte_size,
                               created_at, updated_at, pinned, deleted_at,
                               cloud_record_id, cloud_modified_at, needs_sync)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, ?, 0)
            ON CONFLICT(id) DO UPDATE SET
                kind = excluded.kind,
                content_hash = excluded.content_hash,
                payload_text = excluded.payload_text,
                payload_path = excluded.payload_path,
                preview = excluded.preview,
                source_bundle = excluded.source_bundle,
                source_name = excluded.source_name,
                byte_size = excluded.byte_size,
                updated_at = excluded.updated_at,
                pinned = excluded.pinned,
                cloud_record_id = excluded.cloud_record_id,
                cloud_modified_at = excluded.cloud_modified_at,
                needs_sync = 0
            WHERE excluded.cloud_modified_at > items.cloud_modified_at
               OR items.cloud_modified_at IS NULL
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
        bindTextOptional(stmt, 13, item.cloudRecordID)
        if let cma = item.cloudModifiedAt {
            sqlite3_bind_int64(stmt, 14, Int64(cma.timeIntervalSince1970))
        } else {
            sqlite3_bind_null(stmt, 14)
        }
        try step(stmt)
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
            let cloudRecordID = textOrNil(stmt, 12)
            let cloudModifiedAt: Date? = sqlite3_column_type(stmt, 13) == SQLITE_NULL
                ? nil
                : Date(timeIntervalSince1970: Double(sqlite3_column_int64(stmt, 13)))
            let needsSync = sqlite3_column_int(stmt, 14) != 0
            out.append(ClipboardItem(
                id: id, kind: kind, contentHash: hash,
                payloadText: payloadText, payloadPath: payloadPath,
                preview: preview, sourceBundle: bundle, sourceName: name,
                byteSize: byteSize, createdAt: createdAt, updatedAt: updatedAt, pinned: pinned,
                cloudRecordID: cloudRecordID, cloudModifiedAt: cloudModifiedAt, needsSync: needsSync
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
