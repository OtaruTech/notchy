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

    /// Highlighted card in the panel. Mutated by AppDelegate's key monitor
    /// (←/→ arrows) and the panel itself (hover / direct click).
    var selectedIndex: Int = 0

    var query: String = "" {
        didSet {
            selectedIndex = 0
            Task { await refreshSearch() }
        }
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

    func moveSelection(by delta: Int) {
        let max = displayed.count - 1
        guard max >= 0 else { selectedIndex = 0; return }
        selectedIndex = Swift.max(0, Swift.min(max, selectedIndex + delta))
    }

    func selectFirst() { selectedIndex = 0 }

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
