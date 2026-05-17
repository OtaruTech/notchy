import Foundation
import CloudKit

/// `ClipboardItem` ↔ `CKRecord` conversion. Pure functions, no I/O. Lives
/// in its own file so the data shape is reviewable independent of the
/// engine, and so we can unit-test the round-trip without ever talking to
/// CloudKit servers.
///
/// CloudKit container (Phase B): `iCloud.tech.otaru.Notchy`
/// Record type:                    `ClipboardItem`
/// Zone:                            user's private database default zone
enum CloudKitMapping {

    /// Record type name used in the CloudKit dashboard schema.
    static let recordType = "ClipboardItem"

    // MARK: ClipboardItem → CKRecord (upload)

    static func record(from item: ClipboardItem, zoneID: CKRecordZone.ID = CKRecordZone.ID(zoneName: CKRecordZone.ID.defaultZoneName)) -> CKRecord {
        let recordID = CKRecord.ID(
            recordName: item.cloudRecordID ?? item.id.uuidString,
            zoneID: zoneID
        )
        let record = CKRecord(recordType: recordType, recordID: recordID)
        record["localID"]      = item.id.uuidString as CKRecordValue
        record["kind"]         = item.kind.rawValue as CKRecordValue
        record["contentHash"]  = item.contentHash as CKRecordValue
        record["payloadText"]  = item.payloadText as CKRecordValue?
        record["preview"]      = item.preview as CKRecordValue
        record["sourceBundle"] = item.sourceBundle as CKRecordValue?
        record["sourceName"]   = item.sourceName as CKRecordValue?
        record["byteSize"]     = item.byteSize as CKRecordValue
        record["createdAt"]    = item.createdAt as CKRecordValue
        record["updatedAt"]    = item.updatedAt as CKRecordValue
        record["pinned"]       = (item.pinned ? 1 : 0) as CKRecordValue

        // Image / file payload → CKAsset attached.
        if let path = item.payloadPath, FileManager.default.fileExists(atPath: path.path) {
            record["payloadAsset"] = CKAsset(fileURL: path)
        }
        return record
    }

    // MARK: CKRecord → ClipboardItem (download)

    static func item(from record: CKRecord) -> ClipboardItem? {
        guard
            let kindRaw  = record["kind"] as? String,
            let kind     = ClipboardItem.Kind(rawValue: kindRaw),
            let hash     = record["contentHash"] as? String,
            let preview  = record["preview"] as? String,
            let created  = record["createdAt"] as? Date,
            let updated  = record["updatedAt"] as? Date,
            let localIDStr = record["localID"] as? String,
            let localID  = UUID(uuidString: localIDStr)
        else { return nil }

        let byteSize = (record["byteSize"] as? NSNumber)?.intValue ?? 0
        let pinned = ((record["pinned"] as? NSNumber)?.intValue ?? 0) != 0

        // CKAsset → local file URL (CloudKit stages the file in /tmp).
        var payloadPath: URL?
        if let asset = record["payloadAsset"] as? CKAsset, let url = asset.fileURL {
            payloadPath = url
        }

        return ClipboardItem(
            id: localID,
            kind: kind,
            contentHash: hash,
            payloadText: record["payloadText"] as? String,
            payloadPath: payloadPath,
            preview: preview,
            sourceBundle: record["sourceBundle"] as? String,
            sourceName: record["sourceName"] as? String,
            byteSize: byteSize,
            createdAt: created,
            updatedAt: updated,
            pinned: pinned,
            cloudRecordID: record.recordID.recordName,
            cloudModifiedAt: record.modificationDate ?? updated,
            needsSync: false
        )
    }
}
