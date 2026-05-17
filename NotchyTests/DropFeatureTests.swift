import Testing
import Foundation
@testable import Notchy

@MainActor
struct DropFeatureTests {
    @Test func startsEmpty() {
        let f = DropFeature()
        #expect(f.items.isEmpty)
    }

    @Test func addAppendsItem() {
        let f = DropFeature()
        f.add(.init(url: URL(fileURLWithPath: "/tmp/a.txt")))
        #expect(f.items.count == 1)
        #expect(f.items.first?.displayName == "a.txt")
    }

    @Test func removeStripsById() {
        let f = DropFeature()
        let item = DropItem(url: URL(fileURLWithPath: "/tmp/b.txt"))
        f.add(item)
        f.remove(item.id)
        #expect(f.items.isEmpty)
    }

    @Test func clearAllEmpties() {
        let f = DropFeature()
        f.add(.init(url: URL(fileURLWithPath: "/tmp/a")))
        f.add(.init(url: URL(fileURLWithPath: "/tmp/b")))
        f.clearAll()
        #expect(f.items.isEmpty)
    }
}
