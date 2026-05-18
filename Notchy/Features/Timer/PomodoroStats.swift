import Foundation

/// Snapshot of pomodoro stats consumed by TimerView and DashboardView. Built
/// from PomodoroLog at render time; cheap to recompute every frame.
struct PomodoroStats: Equatable, Sendable {
    let totalToday: Int
    let minutesToday: Int
    let last7: [Int]    // oldest first, today last
    let streak: Int
}
