import Foundation
import Observation

@MainActor
@Observable
final class NotchStateMachine {

    private(set) var state: NotchState = .idle
    private(set) var mediaAvailable: Bool = false
    /// Last tab the user explicitly switched to via the tab bar. Restored on the
    /// next hover-expand so the panel doesn't always snap back to Now Playing.
    /// Reset to nil when media becomes unavailable.
    private(set) var stickyTab: NotchState? = nil

    func send(_ intent: NotchIntent) {
        let new = reduce(state: state, intent: intent)
        guard new != state else { return }
        state = new
    }

    private func reduce(state: NotchState, intent: NotchIntent) -> NotchState {
        switch intent {

        case .mediaAvailabilityChanged(let available):
            mediaAvailable = available
            if available {
                return state == .idle ? .hint : state
            } else {
                switch state {
                case .media, .hint: return .idle
                default: return state
                }
            }

        case .hoverEntered:
            // Hover always expands. Restore last user-pinned tab if any, else
            // prefer .media when playing, else .dashboard.
            if state == .idle || state == .hint {
                if let sticky = stickyTab, sticky.isExpanded { return sticky }
                return mediaAvailable ? .media : .dashboard
            }
            return state

        case .hoverExited:
            // Collapse from any hover-driven expansion.
            if state.isExpanded {
                return mediaAvailable ? .hint : .idle
            }
            return state

        case .dragEntered:
            return .drop

        case .dragExited, .dropCompleted:
            if state == .drop {
                return mediaAvailable ? .hint : .idle
            }
            return state

        case .airPodsConnected:
            return .airpods

        case .dismissTimerFired:
            if state == .airpods {
                return mediaAvailable ? .hint : .idle
            }
            return state

        case .escapeKeyPressed, .outsideClicked:
            return mediaAvailable ? .hint : .idle

        case .calendarAvailabilityChanged:
            return state

        case .timerStarted:
            return .timer

        case .timerTicked:
            return state

        case .timerCompleted:
            return mediaAvailable ? .hint : .idle

        case .tabSwitchedTo(let target):
            // Only meaningful while expanded — remember and apply.
            if state.isExpanded {
                stickyTab = target
                return target
            }
            return state

        case .mirrorRequested:
            return .mirror

        case .clipboardRequested:
            return .clipboard
        }
    }
}
