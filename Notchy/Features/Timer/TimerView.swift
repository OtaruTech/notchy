import SwiftUI

struct TimerView: View {
    let state: TimerFeature.State
    let progress: Double
    var onStart: (TimeInterval) -> Void = { _ in }
    var onPause: () -> Void = {}
    var onResume: () -> Void = {}
    var onReset: () -> Void = {}

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.1), lineWidth: 4)
                    .frame(width: 76, height: 76)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(colors: [.red, .orange],
                                       startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 76, height: 76)
                Text(timeText)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 8) {
                if isIdle {
                    HStack(spacing: 6) {
                        presetChip("25m", 1500)
                        presetChip("15m", 900)
                        presetChip("5m", 300)
                    }
                } else {
                    HStack(spacing: 8) {
                        Button(isRunning ? "Pause" : "Resume") {
                            isRunning ? onPause() : onResume()
                        }
                        Button("Reset", action: onReset)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundStyle(.white)
                }
            }
            Spacer()
        }
    }

    private var isIdle: Bool {
        if case .idle = state { return true }
        return false
    }

    private var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    private var timeText: String {
        let secs: TimeInterval
        switch state {
        case .idle: secs = 0
        case .running(let r, _), .paused(let r, _): secs = r
        }
        let s = Int(secs)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    @ViewBuilder
    private func presetChip(_ label: String, _ seconds: TimeInterval) -> some View {
        Button {
            onStart(seconds)
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.white.opacity(0.1), in: Capsule())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}
