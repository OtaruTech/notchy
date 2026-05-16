import Foundation

/// External signals that the state machine reacts to.
enum NotchIntent: Equatable, Sendable {
    case hoverEntered
    case hoverExited
    case dragEntered
    case dragExited
    case dropCompleted
    case escapeKeyPressed
    case outsideClicked
    case mediaAvailabilityChanged(Bool)
    case airPodsConnected
    case dismissTimerFired
}
