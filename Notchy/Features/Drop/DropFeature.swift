import Foundation
import Observation

@MainActor
@Observable
final class DropFeature {
    private(set) var items: [DropItem] = []

    func add(_ item: DropItem) {
        items.append(item)
    }

    func add(urls: [URL]) {
        for url in urls { add(DropItem(url: url)) }
    }

    func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
    }

    func clearAll() {
        items.removeAll()
    }
}
