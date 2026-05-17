import Foundation

/// Abstract interface for any backend that wants to mirror the local
/// clipboard store to a remote service. The concrete implementations live
/// alongside this file:
///
/// - `NoopSyncEngine` — current production behaviour, does nothing
/// - `CloudKitSyncEngine` — Phase-B stub, will flip on once a paid Apple
///   Developer account + CloudKit container are provisioned
///
/// Lifecycle: AppDelegate creates the engine at launch, calls `start()`
/// once the store is open, and `stop()` on app quit. The engine is
/// expected to push local changes (items with `needs_sync = 1`) on a
/// timer + on `noteLocalChange()`, and pull remote changes via whatever
/// notification mechanism the backend exposes.
@MainActor
protocol SyncEngine: AnyObject {
    /// Identifier for diagnostics / Settings UI ("Off" / "iCloud" / …).
    var displayName: String { get }

    /// True ⇒ the engine actively pushes/pulls. False ⇒ no-op.
    var isActive: Bool { get }

    func start(store: ClipboardStore)
    func stop()

    /// Called by ClipboardFeature whenever an item was inserted / deleted
    /// locally — the engine schedules a push.
    func noteLocalChange()

    /// Manually trigger a full push of everything `needs_sync = 1`.
    /// Useful for a "Sync now" button in Settings later.
    func pushPending() async
}
