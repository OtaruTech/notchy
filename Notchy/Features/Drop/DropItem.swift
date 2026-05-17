import Foundation

struct DropItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let url: URL
    let displayName: String
    let typeIdentifier: String

    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.displayName = url.lastPathComponent
        self.typeIdentifier = (try? url.resourceValues(forKeys: [.typeIdentifierKey]))?
            .typeIdentifier ?? "public.data"
    }
}
