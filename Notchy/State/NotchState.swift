import Foundation

/// What the notch overlay is currently showing.
enum NotchState: Equatable, Sendable {
    case idle
    case hint
    case media
    case drop
    case airpods

    var isExpanded: Bool {
        switch self {
        case .idle, .hint: return false
        case .media, .drop, .airpods: return true
        }
    }
}
