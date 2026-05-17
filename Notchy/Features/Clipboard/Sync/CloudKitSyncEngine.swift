import Foundation
import CloudKit

/// Phase-B CloudKit engine. **Currently inactive** — left wired so the
/// final activation is a one-line change in AppDelegate (`NoopSyncEngine()`
/// → `CloudKitSyncEngine(containerID:)`) plus an entitlement bump.
///
/// To turn this on you need:
/// 1. Apple Developer Program membership ($99/yr)
/// 2. An iCloud container in Apple Developer Portal:
///    `iCloud.tech.otaru.Notchy`
/// 3. `com.apple.developer.icloud-container-identifiers` +
///    `com.apple.developer.icloud-services = [CloudKit]` in entitlements
/// 4. The CloudKit dashboard `ClipboardItem` record type schema deployed
///    (see CloudKitMapping.swift for the field list)
///
/// The first push after activation will upload everything `needs_sync = 1`,
/// which is every existing local item (because the Phase-A migration
/// defaulted `needs_sync` to 1). After that it pushes incrementally.
@MainActor
final class CloudKitSyncEngine: SyncEngine {
    let displayName = "iCloud"
    private(set) var isActive: Bool = false

    private let containerID: String
    private weak var store: ClipboardStore?
    private var pushScheduled: Bool = false

    init(containerID: String) {
        self.containerID = containerID
    }

    func start(store: ClipboardStore) {
        self.store = store
        Task { await checkAccount() }
    }

    func stop() {
        isActive = false
    }

    func noteLocalChange() {
        guard isActive, !pushScheduled else { return }
        pushScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.pushScheduled = false
            Task { await self?.pushPending() }
        }
    }

    func pushPending() async {
        guard isActive, let store = store else { return }
        guard let pending = try? await store.itemsNeedingSync(limit: 100), !pending.isEmpty else {
            return
        }
        // TODO(Phase B): actually wire this up with CKModifyRecordsOperation:
        //
        //   let container = CKContainer(identifier: containerID)
        //   let database  = container.privateCloudDatabase
        //   let toSave    = pending.filter { /* not soft-deleted */ }
        //                          .map { CloudKitMapping.record(from: $0) }
        //   let toDelete  = pending.filter { /* soft-deleted */ }
        //                          .compactMap { $0.cloudRecordID }
        //                          .map { CKRecord.ID(recordName: $0) }
        //   let op = CKModifyRecordsOperation(recordsToSave: toSave, recordIDsToDelete: toDelete)
        //   op.savePolicy = .changedKeys
        //   op.modifyRecordsResultBlock = { result in … markSynced(…) … }
        //   database.add(op)
        _ = pending
    }

    /// Probes `CKContainer.accountStatus` — only flips `isActive = true`
    /// when the user is logged in to iCloud and the container is set up.
    private func checkAccount() async {
        // TODO(Phase B):
        //   let container = CKContainer(identifier: containerID)
        //   let status = try await container.accountStatus()
        //   self.isActive = (status == .available)
        //
        // For Phase A we keep it dormant. Until isActive is true, every
        // public entry point above no-ops.
        isActive = false
    }
}
