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
    case calendarAvailabilityChanged(Bool)
    case timerStarted
    case timerTicked
    case timerCompleted
    case tabSwitchedTo(NotchState)
}
