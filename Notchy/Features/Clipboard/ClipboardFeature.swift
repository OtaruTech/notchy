import Foundation
import Observation

/// Main-actor orchestrator over the clipboard system. UI observes `recent` /
/// `searchResults`; capturer pushes new items via `noteInserted(_:)`.
@MainActor
@Observable
final class ClipboardFeature {

    private(set) var recent: [ClipboardItem] = []
    private(set) var searchResults: [ClipboardItem] = []
    private(set) var count: Int = 0

    var query: String = "" {
        didSet { Task { await refreshSearch() } }
    }

    private let store: ClipboardStore
    private let recentLimit = 100

    init(store: ClipboardStore) {
        self.store = store
    }

    func bootstrap() async {
        await reload()
    }

    /// Called by the capturer right after a new item lands in the store.
    func noteInserted(_ item: ClipboardItem) {
        // Move-to-front if already in recent (dedupe bump), else prepend.
        recent.removeAll { $0.id == item.id }
        recent.insert(item, at: 0)
        if recent.count > recentLimit { recent.removeLast(recent.count - recentLimit) }
        count += 1
        if !query.isEmpty { Task { await refreshSearch() } }
    }

    func reload() async {
        do {
            recent = try await store.recent(limit: recentLimit)
            count = try await store.count()
        } catch {
            recent = []
            count = 0
        }
        await refreshSearch()
    }

    func refreshSearch() async {
        guard !query.isEmpty else { searchResults = []; return }
        do {
            searchResults = try await store.search(query, limit: recentLimit)
        } catch {
            searchResults = []
        }
    }

    func delete(_ item: ClipboardItem) async {
        try? await store.softDelete(id: item.id)
        recent.removeAll { $0.id == item.id }
        searchResults.removeAll { $0.id == item.id }
        count = max(0, count - 1)
    }

    func clearAll() async {
        try? await store.clearAll()
        recent = []
        searchResults = []
        count = 0
    }

    /// Items the UI should render — search results when querying, else recent.
    var displayed: [ClipboardItem] {
        query.isEmpty ? recent : searchResults
    }
}
