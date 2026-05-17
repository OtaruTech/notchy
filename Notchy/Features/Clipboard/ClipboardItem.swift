import Foundation

/// One row in the clipboard history. Immutable; the store creates new copies
/// on update (e.g., `updatedAt` bumps on dedupe match).
struct ClipboardItem: Identifiable, Equatable, Sendable, Hashable {
    let id: UUID
    let kind: Kind
    let contentHash: String        // SHA-256 of the canonical payload
    let payloadText: String?       // text / rtf / url / color / code
    let payloadPath: URL?          // file:// URL pointing at an asset on disk (images, file refs)
    let preview: String            // short display string ready for list view
    let sourceBundle: String?      // e.g. com.apple.Safari
    let sourceName: String?        // "Safari"
    let byteSize: Int              // approximate (text length OR file size)
    let createdAt: Date
    let updatedAt: Date
    let pinned: Bool

    enum Kind: String, Sendable, CaseIterable, Codable {
        case text       // any plain text
        case richtext   // RTF — payloadText holds RTF source
        case url        // single URL with http(s) scheme
        case image      // payloadPath → PNG on disk
        case file       // payloadPath → arbitrary file URL the user copied
        case color      // payloadText = hex (#RRGGBB[AA]) or rgb()/rgba() string
        case code       // multi-line code-ish text
    }
}

extension ClipboardItem.Kind {
    /// SF Symbol used in cards / tabs.
    var sfSymbol: String {
        switch self {
        case .text:     return "text.alignleft"
        case .richtext: return "doc.richtext"
        case .url:      return "link"
        case .image:    return "photo"
        case .file:     return "doc"
        case .color:    return "paintpalette"
        case .code:     return "chevron.left.forwardslash.chevron.right"
        }
    }
}
