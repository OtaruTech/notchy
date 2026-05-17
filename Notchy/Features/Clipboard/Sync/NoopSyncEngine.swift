import Foundation

/// Active production engine: does nothing. The local store still tracks
/// `needs_sync = 1` for every change, so when we swap in CloudKit later,
/// the very first run will push the full backlog.
@MainActor
final class NoopSyncEngine: SyncEngine {
    let displayName = "Local only"
    let isActive = false

    func start(store: ClipboardStore) {}
    func stop() {}
    func noteLocalChange() {}
    func pushPending() async {}
}
