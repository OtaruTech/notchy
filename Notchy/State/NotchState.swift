import Foundation

/// What the notch overlay is currently showing.
enum NotchState: Equatable, Sendable {
    case idle
    case hint
    case dashboard   // default hover-expanded state (clock + date + quick peek)
    case media
    case drop
    case airpods
    case calendar
    case timer

    var isExpanded: Bool {
        switch self {
        case .idle, .hint: return false
        case .dashboard, .media, .drop, .airpods, .calendar, .timer: return true
        }
    }
}
