import Foundation
import Observation
import UserNotifications

@MainActor
@Observable
final class TimerFeature {
    enum State: Equatable {
        case idle
        case running(remaining: TimeInterval, total: TimeInterval)
        case paused(remaining: TimeInterval, total: TimeInterval)
    }

    private(set) var state: State = .idle
    private weak var stateMachine: NotchStateMachine?
    private var tickTask: Task<Void, Never>?
    let log = PomodoroLog()

    init(stateMachine: NotchStateMachine) {
        self.stateMachine = stateMachine
    }

    func start(seconds: TimeInterval) {
        tickTask?.cancel()
        state = .running(remaining: seconds, total: seconds)
        stateMachine?.send(.timerStarted)
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                await MainActor.run { self?.tick() }
            }
        }
    }

    func pause() {
        if case .running(let r, let t) = state {
            tickTask?.cancel()
            state = .paused(remaining: r, total: t)
        }
    }

    func resume() {
        if case .paused(let r, let t) = state {
            state = .running(remaining: r, total: t)
            tickTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    await MainActor.run { self?.tick() }
                }
            }
        }
    }

    func reset() {
        tickTask?.cancel()
        state = .idle
    }

    /// Explicit cleanup — deinit can't access main-actor state in Swift 6.
    func stop() {
        tickTask?.cancel()
        tickTask = nil
    }

    private func tick() {
        if case .running(let r, let t) = state {
            let nr = r - 1
            if nr <= 0 {
                tickTask?.cancel()
                state = .idle
                // Log the completed session so the dashboard + TimerView
                // stats can update. Only log presets that match a focus
                // session (>= 3 min) so accidental short-test runs don't
                // pollute the streak.
                let minutes = Int((t / 60).rounded())
                if minutes >= 3 { log.append(durationMin: minutes) }
                stateMachine?.send(.timerCompleted)
                fireCompletionNotification()
            } else {
                state = .running(remaining: nr, total: t)
                stateMachine?.send(.timerTicked)
            }
        }
    }

    private func fireCompletionNotification() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        let content = UNMutableNotificationContent()
        content.title = "Timer done"
        content.body = "Your timer has finished."
        content.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(req)
    }

    var progress: Double {
        switch state {
        case .running(let r, let t), .paused(let r, let t):
            guard t > 0 else { return 0 }
            return 1 - (r / t)
        case .idle:
            return 0
        }
    }
}
