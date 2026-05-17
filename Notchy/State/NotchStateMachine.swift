import Foundation
import Observation

@MainActor
@Observable
final class NotchStateMachine {

    private(set) var state: NotchState = .idle
    private(set) var mediaAvailable: Bool = false

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
            if mediaAvailable, state == .idle || state == .hint {
                return .media
            }
            return state

        case .hoverExited:
            if state == .media {
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
            return state.isExpanded ? target : state
        }
    }
}
